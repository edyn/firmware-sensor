/*Interactions Outline
http://bit.ly/1OjA8aN should link to googledoc explaining interactions
*/


macAgentSide <- imp.configparams.deviceid;
firebase <- "https://valvetest.firebaseio.com/";
firebaseAuth <- "qxIFLzJKuewlDIGAUXaB3r0pkjO7Ua5LIrcZBPWg";
globalDataStore <- []
globalUnauthorizedActionsStore <- []
defaultSleepTime <- 20.0 //miutes
pathForValveState <- "valveState.json"

function sendDataFromDevice(data) {
    local readingsURL = firebase + "readings.json";
    local headers = {
        "Content-Type":"application/json", 
        "User-Agent":"Imp", 
        "X-Api-Key":firebaseAuth
    };
    local jsonData = http.jsonencode(data);
    //Going to use camelcase where acronyms count as one word, but each letter is treated as the first letter of the acronym:
    //urlReadings is valid, readingsURL is valid, readingsUrl is not.
    local req = http.post(readingsURL, headers, jsonData);
    local res = req.sendsync();
    if (res.statuscode != 200) {
        server.log("Error sending message to Postgres database. Status code: " + res.statuscode);
        return 0
    } else {
        server.log("Readings send successfully to backend.");
        return 1
    }
}
function sendDataHandling(data){

    //TODO: add auth stuff
    server.log("Received readings data from device");
    try {


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
            //default sleep in this mode of failure is 20 minutes, we can change whenver.
            //skipping the get instructions step because we already have a backend failure
            server.log("Problem sending data to the backend!!")
            instructions={"open" : false, "nextCheckIn" : defaultSleepTime};
            device.send("receiveInstructions", instructions);
        }
        //if sending data to server succeeds
        else{
            local instructions = getSuggestedValveState();
            //if fetching instructions fails
            if(!instructions){
                server.log("could not fetch instructions");
                //Adding a default case for in case it could not fetch instructions from backend
                device.send("receiveInstructions", {"open" : false, "nextCheckIn" : defaultSleepTime});
                return 0
            //if fetching instructions succeeds
            }
            else{
                server.log("sending instructions to device");
                device.send("receiveInstructions", instructions);
                return 1
            }
        }

    } catch(error) {
        server.log("Error from device.on(senddata)");
        server.log(error);
    }
}


device.on("sendData", sendDataHandling);


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
    if (res.statuscode != 200) {
        server.log("Error sending message to Postgres database. Status code: " + res.statuscode);
        return 0
    } else {
        server.log("Valve state change acknowledgement send successfully to backend.");
        return 1
    }
}

device.on("valveStateChange", valveStateChangeHandling);


function getSuggestedValveState(){
    //a2e2b needs to be replaced by device specific mac address
    //this url is only for early stage development
    //TODO: add auth stuff
    local url = "https://valvetest.firebaseio.com/valve/20000c2a690a2e2b/now.json"
    local request = http.get(url);
    local response = request.sendsync();
    local statusCode = response.statuscode;
    if(statusCode != 200){
        server.log("Failed to fetch next command");
        //anything that is not false or 0 in squirrel evaluates as True
        return false
    }
    else{
        local resBod = response.body;
        resBod = http.jsondecode(resBod);
        //resBod has two pairs:
        //resBod.open is the 'next suggested valve state'
        //resBod.nextCheckIn is how long the device should sleep for
        return resBod;
    }
}    


device.onconnect(function() { 
    server.log("Device connected to agent");
});


