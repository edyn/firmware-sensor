testsPassed <- [];
testsFailed <- [];

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
    logTest(inputStr = inputStr, passFail = true, inputError = inputError);
}

function logFail(inputStr = "", inputError = false){
    logTest(inputStr = inputStr, passFail = false, inputError = inputError);
}

//testing various inputs to the receiveInstructions() function
function receiveInstructionsTests(){
    //Test 1
    //testing the opening of the valve, should succeed
    //should succeed
    try{
        //open the valve, should be valid
        receiveInstructions({open = true , nextCheckIn = 0.1});
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
        receiveInstructions({open = false , nextCheckIn = 0.1});
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
        receiveInstructions({nextCheckIn = 0.1});
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
        receiveInstructions({open = true});
        //if receiveInstructions passes without error, the test fails
        logFail("receiveInstructions (not enough params, missing 'nextCheckIn')");
    }
    //if there isn't issue in the above test, it failed
    catch(error){
        logPass("receiveInstructions (not enough params, missing 'open')", error);
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
}

receiveInstructionsTests();
testLEDs();
testValve();
imp.sleep(3);
server.log("\nDevice Tests Failed:");
server.log(testsFailed.len());
if(testsFailed.len()>0){
    server.log("\nSpecifically these tests:");
    for (local x = 0; x < testsFailed.len(); x++){
        server.log(testsFailed[x]);
    }
}
server.log("\n");





