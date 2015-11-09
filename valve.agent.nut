/*Interactions Outline
1)Device wakes from sleep
2)Device samples it's sensors, sends that information + current valve state to agent
3)Agent saves this information to backend, 
4)agent retrieves next instruction (next valve state and length of time)
5)Device receives this information, validates it (checks it's power before opening valve, makes sure minutes is a valid value)
6)Valve sends ACK to agent which sends to beckend
7) as soon as ACK is sent, valve goes into deep sleep (ACK is last action taken before sleeping)
*/


macAgentSide <- "";
firebase <- "https://valvetest.firebaseio.com/";
firebaseAuth <- "qxIFLzJKuewlDIGAUXaB3r0pkjO7Ua5LIrcZBPWg";
globalDataStore <- []
defaultSleepTime <- 20.0 //miutes

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
    local req = http.post(readingsURL , headers , jsonData);
    local res = req.sendsync();
    if (res.statuscode != 200) {
        server.log("Error sending message to Postgres database. Status code: " + res.statuscode);
        return 0
    } else {
        server.log("Readings send successfully to backend.");
        return 1
    }
}

device.on("sendData" , function(data) {
    //the next few lines add the device mac address to agent memory
    //surprisingly, there isn't an agent side command to do this.
    //TODO: add auth stuff
    server.log("Received readings data from device")
    try {
        if(macAgentSide == ""){
            server.log("Registering mac address");
            macAgentSide = data.macId;
        }

        //send to server
        //"Do we want to try this if 'senddatafromdevice()'failed?"
        //Good question, I'm going to implement it right now as "tell the valve to sleep a default amount of time"
        //BUT we should handle this better
        //TODO: figure out proper behavior
        //do we tell the valve there was a failure? Is there some change in behavior on the valve?
        sentDataSuccess = sendDataFromDevice(data);
        if(!sendDataSuccess){
            //globalDataStore is the 'log' of actions that failed to send to backend
            //toDo: make sure we don't store too much here if this fails repeatedly
            globalDataStore.append(data)
            //default sleep in this mode of failure is 20 minutes, we can change whenver.
            instructions={"open" : false , "nextCheckIn" : date.time() + defaultSleepTime}
            device.send("receiveInstructions" , instructions);
        }
        //if fetching instructions succeeds
        else
        {
            local instructions = getSuggestedValveState();
            if(!instructions){
                server.log("could not fetch instructions")
            }
            else{
                server.log("sending instructions to device");
                device.send("receiveInstructions" , instructions);
            }
        }
        server.log("retrieving next instruction from the server")

    } catch(error) {
        server.log("Error from device.on(senddata)")
        server.log(error);
    }
});

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
