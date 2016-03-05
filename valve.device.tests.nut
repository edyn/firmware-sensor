testsPassed <- [];
testsFailed <- [];
sampleDataGlobal <- collectData()
//TODO: add a test where timer is greater than time it should sleep.
wakeReason = 1;

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

//testing various inputs to the receiveInstructions() function
function receiveInstructionsTests(){
    //Test 1
    //testing the opening of the valve, should succeed
    //should succeed
    try{
        //open the valve, should be valid
        receiveInstructions({open = true , nextCheckIn = 0.1, iteration = 1}, sampleDataGlobal);
        //if the valve thinks it's valvestate is true, it passes
        if(nv.valveState){
            logPass("Valve Open");
        }
        //if it still thinks it's closed, the test fails
        else{
            logFail("Valve Open");
        }
    }
    //if there's an issue in the above test, it failed
    catch(error){
        logFail("Valve Open", error);
    }
    //Test 2
    //testing closure of the valve, should be reflected in nv.valvestate
    //should succeed
    try{
        //close the valve, should be valid
        receiveInstructions({open = false , nextCheckIn = 0.1, iteration = 0}, sampleDataGlobal);
        //if the valve thinks it's valvestate is false, it passes
        if(!nv.valveState){
            logPass("Valve Close");
        }
        //if it still thinks it's open, the test fails
        else{
            logFail("Valve Close");
        }
    }
    //if there's an issue in the above test, it failed
    catch(error){
        logFail("Valve Close", error);
    }
    //Test 3
    //trying receiveInstructions without an open value
    //should fail
    try{
        receiveInstructions({nextCheckIn = 0.1}, sampleDataGlobal);
        //if receiveInstructions passes without error, the test fails
        logFail("receiveInstructions (not enough params, missing 'open')");
    }
    //if there isn't an issue in the above test, it failed
    catch(error){
        logPass("receiveInstructions (not enough params, missing 'open')", error);
    }
    //Test 4
    //trying receiveInstructions without a nextCheckIn value
    //should fail
    try{
        receiveInstructions({open = true}, sampleDataGlobal);
        //if receiveInstructions passes without error, the test fails
        logFail("receiveInstructions (not enough params, missing 'nextCheckIn')");
    }
    //if there isn't issue in the above test, it failed
    catch(error){
        logPass("receiveInstructions (not enough params, missing 'nextCheckIn')", error);
    }

    //test 5:
    //test sending an open signal without iterating
    //no failure
    nv.iteration = 1;
    open();
    local instructions = {open = true, nextCheckIn = 1, iteration = 1};
    try{
        receiveInstructions(instructions, sampleDataGlobal);
        if(nv.valveState == true){
            logFail("receiveInstructions (failed iteration)");
        }else{
            logPass("receiveInstructions (failed iteration)")
        }
    }
    //if there isn't issue in the above test, it failed
    catch(error){
        logFail("receiveInstructions (failed iteration)", error);
    }
    
    //test 6:
    //test sending an open signal with proper iterating
    //no failure
    nv.iteration = 0;
    close();
    local instructions = {open = true, nextCheckIn = 1, iteration = 1};
    try{
        receiveInstructions(instructions, sampleDataGlobal);
        if(nv.valveState == false){
            logFail("receiveInstructions (proper iteration)");
        }else{
            logPass("receiveInstructions (proper iteration)")
        }
    }
    //if there isn't issue in the above test, it failed
    catch(error){
        logFail("receiveInstructions (proper iteration) caused error", error);
    }
    
    //test 7:
    //test sending a random input or missing iteration parameter
    //should cause an error
    nv.iteration = 0;
    close();
    local instructions = {open = true, nextCheckIn = 1};
    try{
        receiveInstructions(instructions, sampleDataGlobal);
        logFail("receiveInstructions (missing iteration parameter)")
    }
    //if there isn't issue in the above test, it failed
    catch(error){
        logPass("receiveInstructions (missing iteration parameter)", error);
    }
}

//Testing the LED related functions
function testLEDs(){
    //test 1
    //configuring red LED, turning it on and off
    //should pass
    try{
        redConfigure();
        redOn();
        redOff();
        logPass("red LED tests");
    }
    catch(error){
        logFail("red LED tests", error);
    }
    //test 2
    //configuring blue LED, turning it on and off
    //should pass
    try{
        blueConfigure();
        blueOn();
        blueOff();
        logPass("blue LED tests");
    }
    catch(error){
        logFail("blue LED tests", error);
    }
    //test 3
    //configuring green LED, turning it on and off
    //should pass
    try{
        greenConfigure();
        greenOn();
        greenOff();
        logPass("green LED tests");
    }
    catch(error){
        logFail("green LED tests", error);
    }
}

//Testing the valve related functions
function testValve(){
    //test 1:
    //try the valvePinInit function
    //should pass
    try{
        valvePinInit();
        logPass("valve Pin Init");
    }
    catch(error){
        logFail("valve Pin Init", error);
    }
    //test 2:
    //try the valveConfigure function
    //should fail
    try{
        valveConfigure();
        logPass("valve configure");
    }
    catch(error){
        logFail("valve Pin Init", error);
    }
    //test 3:
    //try the open function, check the NV table
    //should pass, should have nv.valvestate equal to true
    try{
        open()
        if(nv.valveState==true){
            logPass("valve open");
        }
        else{
            logFail("valve open");
        }
    }
    catch(error){
        logFail("valve Pin Init", error);
    }
    //test 4:
    //try the close function, check the NV table
    //should pass, should have nv.valvestate equal to false
    try{
        close();
        if(nv.valveState==false){
            logPass("valve close");
        }
        else{
            logFail("valve close");
        }
    }
    catch(error){
        logFail("valve close", error);
    }
    //test 5:
    //valve closes if it fails to connect:
    open();
    try{
        onConnectedCallback(0, sampleDataGlobal);
        if(nv.valveState == false){
            logPass("Valve Disconnect");
        }
        else{
            logFail("Valve Disconnect");
        }
    }
    catch(error){
        logFail("Valve Disconnect", error);
    }
}

function testCharger(){
    try{
        chargingConfigure();
        logPass("charging configure");
    }
    catch(error){
        logFail("charging failure", error);
    }
    try{
        local reading = getBatteryVoltage();
        //battery voltage should always evaluate true (should be greater than 0)
        if(reading){
             logPass("get battery voltage");
        }
        else{
            logFail("battery voltage returns 0, false or nothing");
        }
    }
    catch(error){
        logFail("get battery voltage", error);
    }
    try{
        local reading = getChargeSign();
        if(reading == 1.0 || reading == -1.0){
            logPass("get charge sign");
        }
        else{
            logFail("get charge sign returns invalid value");
        }
    }
    catch(error){
        logFail("get charge sign", error);
    }
    try{
        local reading = getSolarVoltage();
        if(reading >= 0.0 && reading < 6.0){
            logPass("get solar voltage");
        }
        else{
            logFail("get solar voltage");
        }
    }
    catch(error){
        logFail("get solar voltage", error);
    }
    try{
        //this function can return positive, negative or 0
        local reading = getChargeCurrent();
        logPass("get charge current");
    }
    catch(error){
        logFail("get charge current");
    }
    try{
        local chargingTable=getChargingStatus();
        if("battery" in chargingTable && "solar" in chargingTable && "amperage" in chargingTable){
            logPass("get charging status");
        }
        else{
            logFail("get charging status");
        }
    }
    catch(error){
        logFail("get charging status", error);
    }
}

function testCollectData(){
    try{
        local testTable = collectData();
        if("wakeReason" in testTable && "batteryVoltage" in testTable 
            && "solarVoltage" in testTable && "amperage" in testTable 
            && "valveState" in testTable && "timestamp" in testTable 
            && "rssi" in testTable && "OSVersion" in testTable 
            && "hardwareVersion" in testTable && "firmwareVersion" in testTable){
            logPass("collect data");
        }
        else{
            logFail("collect data");
        }    
    }
    catch(error){
        logFail("collect data", error);
    }
}

function testBatterySafety(){
    local sampleData = collectData();
    try{
        sampleData.batteryVoltage = batteryCritical - 0.1;
        open();
        imp.sleep(0.2);
        if(!batteryCriticalCheck(sampleData)){
            if(!nv.valveState){
                logPass("BatteryCriticalCheck");
            } else {
                logFail("BatteryCriticalCheck");
            }

        } else {
            logFail("BatteryCriticalCheck");
        }
    } catch(error){
        logFail("BatteryCriticalCheck", error);
    }
    try{
        sampleData.batteryVoltage = batteryLow - 0.1;
        open();
        imp.sleep(0.2);
        batteryLowCheck(sampleData);
        if(!batteryLowCheck(sampleData)){
            if(!nv.valveState){
                logPass("BatteryLowCheck");
            } else {
                logFail("BatteryLowCheck");
            }
        } else {
            logFail("BatteryLowCheck");
        } 
    } catch(error){
        logFail("BatteryLowCheck", error)
    }
}
/*
function logglyTests(){
    //forcedLogglyConnect
    open();
    forcedLogglyConnect(NO_WIFI);
    try{
        forced
        if(nv.valveState == false && mostRecentDeepSleepCall == criticalBatterySleepTime * 60.0){
            logPass("BatteryCriticalCheck");
        } else {
            logFail("BatteryCriticalCheck");
        }
    } catch(error){
        logFail("BatteryCriticalCheck", error);
    }
    try{
        sampleData.batteryVoltage = batteryLow - 0.1;
        open();
        imp.sleep(0.2);
        batteryLowCheck(sampleData);
        if(nv.valveState == false && mostRecentDeepSleepCall == lowBatterySleepTime * 60.0){
            logPass("BatteryLowCheck");
        } else {
            logFail("BatteryLowCheck");
        } 
    } catch(error){
        logFail("BatteryLowCheck", error)
    }
}
*/

function testErrors(){
    //disobey a
    //expect valve to close (nothing else)
    open();
    nv.iteration=0;
    imp.sleep(0.2);
    throwErrors = "disa";
    try{
        disobey{"unitTestDisobey",sampleDataGlobal}
        if(!nv.valveState){
            logPass("DisobeyErrorTest");
        } else {
            logFail("DisobeyErrorTest");
        } 
    } catch(error){
        logFail("DisobeyErrorTest", error);
    }
    //receive instructions error a
    imp.sleep(0.2);
    open();
    imp.sleep(0.2);
    throwErrors = "reca";
    nv.iteration=0;
    mostRecentDeepSleepCall = 0;
    try{
        receiveInstructions({open = true , nextCheckIn = 0.1, iteration = 1}, sampleDataGlobal);
        if(!nv.valveState && mostRecentDeepSleepCall == sleepOnErrorTime){
            logPass("receiveInstructionsErrorA");
        } else {
            logFail("receiveInstructionsErrorA");
        } 
    } catch(error){
        logFail("receiveInstructionsErrorA", error);
    }
    //receive instructions error b
    imp.sleep(0.2);
    open();
    imp.sleep(0.2);
    throwErrors = "recb";
    nv.iteration=0;
    mostRecentDeepSleepCall = 0;
    try{
        receiveInstructions({open = true , nextCheckIn = 0.1, iteration = 1}, sampleDataGlobal);
        if(!nv.valveState && mostRecentDeepSleepCall == valveCloseMaxSleepTime * 60.0){
            logPass("receiveInstructionsErrorB");
        } else {
            logFail("receiveInstructionsErrorB");
        } 
    } catch(error){
        logFail("receiveInstructionsErrorB", error);
    }
    //receive instructions error c
    imp.sleep(0.2);
    open();
    imp.sleep(0.2);
    throwErrors = "recc";
    nv.iteration=0;
    mostRecentDeepSleepCall = 0;
    try{
        receiveInstructions({open = true , nextCheckIn = 0.1, iteration = 1}, sampleDataGlobal);
        if(!nv.valveState && mostRecentDeepSleepCall == errorSleepTime * 60.0){
            logPass("receiveInstructionsErrorC");
        } else {
            logFail("receiveInstructionsErrorC");
        } 
    } catch(error){
        logFail("receiveInstructionsErrorC", error);
    }  
    //receive instructions error d
    imp.sleep(0.2);
    open();
    imp.sleep(0.2);
    throwErrors = "recd";
    nv.iteration=0;
    mostRecentDeepSleepCall = 0;
    try{
        receiveInstructions({open = true , nextCheckIn = 0.1, iteration = 1}, sampleDataGlobal);
        if(!nv.valveState && mostRecentDeepSleepCall == errorSleepTime * 60.0){
            logPass("receiveInstructionsErrorD");
        } else {
            logFail("receiveInstructionsErrorD");
        } 
    } catch(error){
        logFail("receiveInstructionsErrorD", error);
    }
    //main/initializations error a
    imp.sleep(0.2);
    open();
    imp.sleep(0.2);
    throwErrors = "maia";
    mostRecentDeepSleepCall = 0;
    try{
        main()
        if(!nv.valveState && mostRecentDeepSleepCall == criticalBatterySleepTime * 60.0){
            logPass("mainErrorA");
        } else {
            logFail("mainErrorA");
        } 
    } catch(error){
        logFail("mainErrorA", error);
    }

}



receiveInstructionsTests();
testLEDs();
testValve();
testCharger();
testCollectData();
testBatterySafety();
imp.wakeup(10,function(){
    server.log("\nDevice Tests Failed:");
    server.log(testsFailed.len() + " tests failed out of " + (testsPassed.len() + testsFailed.len()) + " tests total");
    if(testsFailed.len()>0){
        server.log("\nSpecifically these tests:");
        for (local x = 0; x < testsFailed.len(); x++){
            server.log(testsFailed[x]);
        }
    } else {
        server.log("ALL DEVICE TESTS PASSED");
    }
    server.log("\n");
})




