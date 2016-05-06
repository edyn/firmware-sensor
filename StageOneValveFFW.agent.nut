#require "Firebase.class.nut:1.0.0"

const FIREBASE_AUTH_KEY = "jIj6j6B4h8trkbjTXXI7ODT9r8yBrm05RqrIiUME";

firebase <- Firebase("valvemanufacturing", FIREBASE_AUTH_KEY);

macAgentSide <- imp.configparams.deviceid;

allowNewError <- true;

device.on("Not Passed", function(data){
    firebase.write("/"+macAgentSide+"/FirstStageFail/" ,  
                    {
                        "Failed_Test" : data.testFailed, 
                        "Fail_Value" : data.failValue, 
                        "Expected_Value_Minimum" : data.expectedValueMin, 
                        "Expected_Value_Maximum" : data.expectedValueMax
                    });
});

device.on("Passed", function(data){
        firebase.write("/"+macAgentSide+"/FirstStagePass/" ,  
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
        firebase.write("/FirstStageErrors/" + macAgentSide + "/" + time() + "/" ,  
        {
            "error" : data.error
        });
    }
    allowNewError = false;
})

device.onconnect(function(){
    allowNewError = true;
})