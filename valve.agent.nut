macAgentSide<- "";
firebase<-"https://valvetest.firebaseio.com/";
firebaseAuth<-"qxIFLzJKuewlDIGAUXaB3r0pkjO7Ua5LIrcZBPWg";
globalDataStore<-[]


function sendDataFromDevice(data) {
    local readings_url=firebase+"readings.json";
    local headers={
        "Content-Type":"application/json", 
        "User-Agent":"Imp", 
        "X-Api-Key":firebaseAuth
    };
    local jsonData=http.jsonencode(data);
    local req = http.post(readings_url, headers, jsonData);
    local res = req.sendsync();
    if (res.statuscode != 200) {
        server.log("Error sending message to Postgres database. Status code: " + res.statuscode);
        return 0
    } else {
        server.log("Readings sent successfully to Postgres database.");
        return 1
    }
}

device.on("sendData", function(data) {
    //the next few lines add the device mac address to agent memory
    //surprisingly, there isn't an agent side command to do this.
    server.log("Received readings data from device")
    try {
        if(macAgentSide==""){
            server.log("Registering mac address");
            macAgentSide=data.macId;
        }

        //send to firebase
        sentDataSuccess=sendDataFromDevice(data);
        if(!sendDataSuccess){
            globalDataStore.append(data)
        }
        //right now we'll just fake it.
        server.log("retrieving next instruction from firebase")
        local instructions=getSuggestedValveState();
        if(!instructions){
            server.log("could not fetch instructions")
        }
        else{
            server.log("sending instructions to device");
            device.send("receiveInstructions",instructions);
        }
    } catch(error) {
        server.log("Error from device.on(senddata)")
        server.log(error);
    }
});

function getSuggestedValveState(){
    //a2e2b needs to be replaced by device specific mac address
    //this url is only for early stage development
    local url="https://valvetest.firebaseio.com/valve/20000c2a690a2e2b/now.json"
    local request = http.get(url);
    local response = request.sendsync();
    local statusCode=response.statuscode;
    if(statusCode!=200){
        server.log("Failed to fetch next command");
        //anything that is not false or 0 in squirrel evaluates as True
        return false
    }
    //redundant 'else', but helps readability:
    else{
        local resBod=response.body;
        resBod=http.jsondecode(resBod);
        //resBod has two pairs:
        //resBod.open is the 'next suggested valve state'
        //resBod.nextCheckIn is how long the device should sleep for
        return resBod;
    }
}    

device.onconnect(function() { 
    server.log("Device connected to agent");
});
