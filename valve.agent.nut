//Interactions Outline
//http://bit.ly/1OjA8aN should link to googledoc explaining interactions

//GENERAL TODOs:
//add function to send info to loggly
//send all data from globalDataStore and globalUnauthorizedActionsStore
//TRACK ERRORS THROUGH LOGGLY ASAP

#require "Loggly.class.nut:1.0.1"
macAgentSide <- imp.configparams.deviceid;
firebase <- "https://edynpepper.firebaseio.com/";
firebaseAuth <- "1YsKtvLswSYsI4tcCDX62X3ZKh7eU94HeV8dmLf7";
globalDataStore <- []
globalUnauthorizedActionsStore <- []
defaultSleepTime <- 20.0 //miutes
pathForValveState <- "valveState.json"
pathForValveNextAction <- "valves/v1/valves-now/" + macAgentSide + ".json"
pathForValveData <- "http://api.valve.prod.edyn.com/readings/" + macAgentSide
const WAKEREASON_SQUIRREL_ERROR = 5;
bearerAuth <- "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzY29wZXMiOlsicHVibGljIiwidmFsdmU6YWdlbnQiXSwiaWF0IjoxNDU1NzM4MjY4LCJzdWIiOiJhcHA6dmFsdmUtYWdlbnQifQ.-BKIywHrpbtNo2xuYhcZ-4w5itBFQMM0KHQZmXcYgcM";
//This is the FW bandaid that retries if a required field for valve instructions is missing
//sample error message that would trigger this: the index 'nextCheckIn' does not exist (line 76)
fetchInstructionsTryNumberMax <- 1;
//wait this long before retrying:
fetchInstructionsRetryTimer <- 0.5;
unitTesting <- 0;

//Loggly stuff:
logglyKey <- "1890ff8f-0c0a-4ca0-b2f4-74f8f3ea469b"
loggly <- Loggly(logglyKey, { 
    "tags" : "valveLogs",
    "timeout" : 60,
    "limit" : 20 //arbitrary 
});
//example loggly command:
//    loggly.log({
//        "battery" : 4,
//        "power" : 1,
//        "rssi" : 2,
//        "msg" : 3
//    });

function deviceLogglyLog(logTable){
    logTable.macAddress <- macAgentSide;
    logTable.sourceGroup <- "Firmware";
    loggly.log(logTable);
}

function deviceLogglyWarn(logTable){
    logTable.macAddress <- macAgentSide;
    logTable.sourceGroup <- "Firmware";
    loggly.warn(logTable);
}

function deviceLogglyErr(logTable){
    logTable.macAddress <- macAgentSide;
    logTable.sourceGroup <- "Firmware";
    loggly.error(logTable);
}

function disobeyInData(data){
    if("disobeyReason" in data){
        loggly.log({
            "disobey" : data.disobeyReason,
            "macAddress" : macAgentSide
        });
        server.log("Device Disobeyed" + data.disobeyReason);
        return true
    } else {
        return false
    }
}

device.on("requestInstructions", function(data){
    fetchAndSendInstructions(0);
});

function sendDataFromDevice(data) {
    local readingsURL = pathForValveData;
    local headers = {
        "Content-Type":"application/json", 
        "User-Agent":"Imp", 
        "Authorization" : bearerAuth
    };
    local jsonData = http.jsonencode(data);
    //Going to use camelcase where acronyms count as one word, but each letter is treated as the first letter of the acronym:
    //urlReadings is valid, readingsURL is valid, readingsUrl is not.
    local req = http.post(readingsURL, headers, jsonData);
    local res = req.sendsync();
    if("wakeReason" in data){
        if(data.wakeReason == WAKEREASON_SQUIRREL_ERROR){//Waking from squirrel runtime error
            loggly.error({
                "error" : "Valve waking from error"
            });
        }
    }  
    if (res.statuscode != 200 && res.statuscode != 201 && res.statuscode != 202) {
        loggly.warn({
            "message" : "Error sending data",
            "function" : "sendDataFromDevice (agent)",
            "statusCode" : res.statuscode,
            "macAddress" : macAgentSide
        });
        server.log("Error sending message to Postgres database. Status code: " + res.statuscode);
        return res.statuscode
    } else {
        server.log("Readings send successfully to backend.");
        return res.statuscode
    }
}

function sendDataHandling(data){
    local instructions ={}
    //TODO: add auth stuff
    server.log("Received readings data from device");
    try {
        if("batteryVoltage" in data){
            server.log("Battery Voltage: " + data.batteryVoltage);
        }
        if("wakeReason" in data){
            server.log("Wake Reason: " + data.wakeReason);
        }
        if("solarVoltage" in data){
            server.log("Solar Voltage: " + data.solarVoltage);
        }
        if("rssi" in data){
            server.log("RSSI: " + data.rssi);
        }
        //send to server
        //"Do we want to try this if 'senddatafromdevice()'failed?"
        //Good question, I'm going to implement it right now as "tell the valve to sleep a default amount of time"
        //BUT we should handle this better
        //TODO: figure out proper behavior
        //do we tell the valve there was a failure? Is there some change in behavior on the valve?
        local sendDataSuccess = sendDataFromDevice(data);
        if(!sendDataSuccess){
            //globalDataStore is the 'log' of actions that failed to send to backend
            //toDo: make sure we don't store too much here if this fails repeatedly
            globalDataStore.append(data);
            //TODO: review if we actually want to skip trying to receive instructions, this might change in the future
            //default sleep in this mode of failure is 20 minutes, we can change whenver.
            //skipping the get instructions step because we already have a backend failure
            server.log("Problem sending data to the backend!!") //already logged as a warning in sendDataFromDevice()
            //TODO: add receive instructions error handling.
        }
    //if there's an error in this function, just tell the valve to go to sleep.
    } catch(error){
        server.log(error);
        loggly.error({
            "error" : error,
            "function" : "sendDataHandling",
            "macAddress" : macAgentSide 
        });

    }
}

function fetchAndSendInstructions(tryNumber){
    try{
        local instructions = getSuggestedValveState();
        //if fetching instructions fails
        if(!instructions){
            server.log("could not fetch instructions");
            //Adding a default case for in case it could not fetch instructions from backend
            instructions = {"open" : false, "nextCheckIn" : defaultSleepTime, iteration = 0}
            device.send("receiveInstructions", instructions);
            return 0
            //if fetching instructions succeeds
        } else {
            server.log("sending instructions to device: " + instructions.open + " for " + instructions.nextCheckIn + "minutes.");
            device.send("receiveInstructions", instructions);
            return 1
        }    
    } catch(error) {
        server.log("Error in fetchAndSendInstructions:")
        loggly.error({
            "error" : error,
            "function" : "fetchAndSendInstructions (agent)",
            "tryNumber" : tryNumber,
            "macAddress" : macAgentSide
        });
        server.log(error);
        //retry on error 
        if(tryNumber < fetchInstructionsTryNumberMax){
            imp.sleep(0.5)
            server.log("trying fetch instructions for the " + (tryNumber + 1) + "time.");
            fetchAndSendInstructions(tryNumber + 1);
        } else {
            server.log("Repeated error from fetchAndSendInstructions(), sending default instructions");
            local defaultInstructions = {"open" : false, "nextCheckIn" : defaultSleepTime, iteration = 0};
            device.send("receiveInstructions", defaultInstructions);
        }
    }
}

device.on("sendData", sendDataHandling);

//TODO: we could add "reason" to the data passed to this function if we wanted, I.E. "unexpected"
function valveStateChangeHandling(data){
    local valveStateURL = firebase + pathForValveState;
    local headers = {
        "Content-Type":"application/json", 
        "User-Agent":"Imp", 
        "X-Api-Key":firebaseAuth
    };
    local jsonData = http.jsonencode(data);
    //Going to use camelcase where acronyms count as one word, but each letter is treated as the first letter of the acronym:
    //urlReadings is valid, readingsURL is valid, readingsUrl is not.
    local req = http.post(valveStateURL, headers, jsonData);
    local res = req.sendsync();
    //TODO: make generic handling function for HTTP requests
    if (res.statuscode != 200 && res.statuscode != 201 && res.statuscode != 202) {
        loggly.warn({
            "warning" : "Error sending message",
            "function" : "valveStateChangeHandling (agent)",
            "statusCode" : res.statuscode,
            "macAddress" : macAgentSide
        });
        server.log("Error sending message to Postgres database. Status code: " + res.statuscode);
        return res.statuscode
    } else {
        server.log("Valve state change acknowledgement send successfully to backend.");
        return res.statuscode
    }
}

device.on("valveStateChange", valveStateChangeHandling);
device.on("logglyLog", deviceLogglyLog);//not sure if this will work, gotta test it
device.on("logglyWarn", deviceLogglyWarn);//not sure if this will work, gotta test it
device.on("logglyError", deviceLogglyErr);//not sure if this will work, gotta test it

function getSuggestedValveState(){
    //TODO: add auth stuff
    local url = firebase + "/" + pathForValveNextAction;
    local request = http.get(url);
    local response = request.sendsync();
    local statusCode = response.statuscode;
    local resBod = response.body;
    resBod = http.jsondecode(resBod);
    //TODO: make generic handling function for HTTP requests
    if(statusCode != 200 && statusCode != 201 && statusCode != 202){
        loggly.warn({
            "warning" : "Failed to fetch next command",
            "function" : "getSuggestedValveState (agent)",
            "statusCode" : statusCode,
            "macAddress" : macAgentSide
        });
        server.log("Failed to fetch next command, status code: " + statusCode);
        //anything that is not false or 0 in squirrel evaluates as True
        return false
    }
    else{
        server.log("Readings sucessfully retrieved")
        local resBod = response.body;
        resBod = http.jsondecode(resBod);
        //resBod has two pairs:
        //resBod.open is the 'next suggested valve state' - boolean
        //resBod.nextCheckIn is how long the device should sleep for - float minutes from now
        return resBod;
    }
}    


device.onconnect(function() { 
    server.log("Device connected to agent");
    loggly.log({
        "deviceConnected" : time(),
        "macAddress" : macAgentSide
    });
});



function retrySendingDataIfNeeded(){
    //globalDataStore.len() is called many times rather than being a single variable because it changes throughout the function.
    if(globalDataStore.len()){
        local initialNumber = globalDataStore.len();
        local lastResponse = 0;
        local currentReading = {};
        local unsentReadingsTemp = []
        if(globalDataStore.len() > 100){
            server.log("Over 100 unsent readings");
            deviceLogglyWarn({"warning" : globalDataStore.len() + "unsent readings!"})
        }
        while(globalDataStore.len() > 0){
            server.log("Found " + globalDataStore.len() + " unsent readings, attempting to send them now")
            currentReading=globalDataStore.remove(0);
            lastResponse = sendDataFromDevice(currentReading);
            if(lastResponse < 200 || lastResponse > 203){
                server.log("A stored reading was unsuccessful on it's retry, will try again later");
                unsentReadingsTemp.append(currentReading)
            } else {
                server.log("A stored reading was sent successfully");
            }
        }
        if(globalDataStore.len()>0){
            server.log("Unsent Readings Remaining: " + globalDataStore.len());
        } else if(initialNumber){
            server.log("sent all unsent readings, " + initialNumber + " in total.");
        }
        globalDataStore = unsentReadingsTemp;
    }
    if(!unitTesting){
        imp.wakeup(60,retrySendingDataIfNeeded);
    }
}
if(!unitTesting){
    retrySendingDataIfNeeded();
}

