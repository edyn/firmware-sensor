#require "Firebase.class.nut:1.0.0"

const FIREBASE_AUTH_KEY = "jIj6j6B4h8trkbjTXXI7ODT9r8yBrm05RqrIiUME";

firebase <- Firebase("valvemanufacturing", FIREBASE_AUTH_KEY);

macAgentSide <- imp.configparams.deviceid;

device.on("testresult", function(data) {
    local url = "https://edynfactory.firebaseio.com/valves/tests.json";
    local headers = { "Content-Type":"application/json" };
    local body = http.jsonencode(data);
    local deviceid = imp.configparams.deviceid;
    server.log(format("posting testresults for device %s:%s", deviceid, body));
    http.post(url, headers, body).sendasync(function (response) {
        if (response.statuscode >= 300) {
            server.error(format(
                "failed posting testresults for device %s with status code %d:%s",
                deviceid, response.statuscode, response.body));
        }
    });
});



allowNewError <- true;

device.on("Not Passed", function(data){
    firebase.write("/"+macAgentSide+"/SecondStageFail/" ,  
                    {
                        "Failed_Test" : data.testFailed, 
                        "Fail_Value" : data.failValue, 
                        "Expected_Value_Minimum" : data.expectedValueMin, 
                        "Expected_Value_Maximum" : data.expectedValueMax
                    });
});

device.on("Passed", function(data){
        firebase.write("/"+macAgentSide+"/SecondStagePass/" ,  
                    {
                        "Tests Passed" : true, 
                        "RSSI" : data.RSSI, 
                        "Solar Voltage" : data.Solar_Voltage, 
                        "Battery Voltage" : data.Battery_Voltage,
                        "Charger Current" : data.Amperage
                    });
})

device.on("error", function(data){  
    if(allowNewError){
        firebase.write("/SecondStageErrors/" + macAgentSide + "/" + time() + "/" ,  
        {
            "error" : data.error
        });
    }
    allowNewError = false;
})

device.onconnect(function(){
    allowNewError = true;
})