macAgentSide<- "";
firebase<-"https://valvetest.firebaseio.com/";
firebaseAuth<-"qxIFLzJKuewlDIGAUXaB3r0pkjO7Ua5LIrcZBPWg";

function send_data_json_node(data) {
    local readings_url = firebase;
    local urlConcatenation=readings_url+"readings.json";
    local headers={
        "Content-Type":"application/json", 
        "User-Agent":"Imp", 
        "X-Api-Key":firebaseAuth
    };
    local jsonData=http.jsonencode(data);
    local req = http.post(urlConcatenation, headers, jsonData);
    local res = req.sendsync();
    if (res.statuscode != 200) {
        server.log("Error sending message to Postgres database. Status code: " + res.statuscode);
        return 0
    } else {
        server.log("Data sent successfully to Postgres database.");
        return 1
    }
}

device.on("sendData", function(data) {
    //the next few lines add the device mac address to agent memory
    //surprisingly, there isn't an agent side command to do this.
    if(macAgentSide==""){
        server.log("Registering mac address");
        macAgentSide=data.macId;
    };
    //send to firebase
    send_data_json_node(data);
    //right now we'll just fake it.
    server.log("retrieving next instruction from firebase")
    local instructions=getSuggestedValveState();
    server.log("sending instructions to device");
    device.send("receiveInstructions",instructions);
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
