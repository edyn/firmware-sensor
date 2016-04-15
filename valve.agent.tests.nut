
firebaseAuthTemp <- "";
firebaseAuthTemp = firebaseAuth;
testsPassed <- [];
testsFailed <-[];

//this
realDataTable <- {
    macId = "20000c2a690a2e2b",
    wakeReason = 0,
    batteryVoltage = 3.3,
    solarVoltage = 3.4,
    amperage = 1.0,
    valveState = true,
    timestamp = date().time,
    rssi = (-60),
    OSVersion = "AnyString",
    hardwareVersion = "AnyString",
    firmwareVersion = "AnyString"
}

function logTest(inputStr = "", passFail = false, inputError = false){
    if(passFail){
        if(inputError){
            server.log(inputStr + " Success with intentional error " + inputError);
        }else{
            server.log(inputStr + " Success");
        }
        testsPassed.append(inputStr);
    }else{
        if(inputError){
            server.log(inputStr + "Failure with error " + inputError);
        }else{
            server.log(inputStr + "Failure");
        }
        testsFailed.append(inputStr);
    }
}

function logPass(inputStr = "", inputError = false){
    logTest(inputStr, true, inputError);
}

function logFail(inputStr = "", inputError = false){
    logTest(inputStr, false, inputError);
}

function sendDataFromDeviceTests(){

    //test 1: regular operation with dummy data inputs should no longer succeed 
    //but a failure is probably due to a backend issue?
    try{
        local statusCode = sendDataFromDevice({dummyData = "Random Inputs Shouldn't Succeed"});
        if(statusCode != 200 && statusCode != 201 && statusCode != 202 && statusCode != 203){
            logPass("sendDataFromDevice (random inputs)");
        }
        else{
            logFail("sendDataFromDevice (random inputs)");
        }
    }
    catch(error){
        logFail("sendDataFromDevice (random inputs)", error)
    }
    //test 2: trying to send with invalid authorization should fail
    local tempAuth = bearerAuth;
    bearerAuth = "IncorrectAuth";
    try{
        local statusCode = sendDataFromDevice({dummyData = "Random Inputs Should Succeed"});
        //(opposite of previous comment) Anything we send shoudl fail in this test because we are inputting a bad API key
        //TODO: handle 4xx and 5xx differently from one another.
        if(statusCode != 200 && statusCode != 201 && statusCode != 202 && statusCode != 203){
            logPass("sendDataFromDevice (bad auth)");
        }
        else{
            logFail("sendDataFromDevice (bad auth)");    
        }
    }
    catch(error){
        logFail("sendDataFromDevice (bad auth)", error);
    }
    bearerAuth = tempAuth;
    //same as last test but with regular data
    try{
        local statusCode = sendDataFromDevice(realDataTable);
        //anything should work when new rules are implemented.
        //TODO: handle 4xx and 5xx differently from one another.
        if(statusCode != 200 && statusCode != 201 && statusCode != 202 && statusCode != 203){
            logFail("sendDataFromDevice (real data)")
        }
        else{
            logPass("sendDataFromDevice (real data)")
        }
    }

    //still shouldn't throw an error, so this should be considered a failure in either case
    catch(error){
            logFail("sendDataFromDevice (real data)",error)
    }  
    //test 4: send from globaldatastore:
    try{
        globalDataStore.append(realDataTable);
        globalDataStore.append(realDataTable);
        globalDataStore.append(realDataTable);
        globalDataStore.append(realDataTable);
        retrySendingData();
        if(globalDataStore.len()==0){
            logPass("RetrySendingData");
        } else {
            logFail("RetrySendingData");
        }
    } catch (error) {
        logFail("RetrySendingData", error)
    }
}

sendDataFromDeviceTests();
imp.wakeup(15,function(){
    server.log("\nAgent Tests Failed:");
    server.log(testsFailed.len() + " out of " + (testsPassed.len()+testsFailed.len()) + " tests total");
    if(testsFailed.len()>0){
        server.log("\nSpecifically these tests:");
        for (local x = 0; x < testsFailed.len(); x++){
            server.log(testsFailed[x]);
        }
    }
    server.log("\n");
})
