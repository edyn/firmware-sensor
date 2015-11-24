testsPassed <- [];
testsFailed <- [];

function logTest(inputStr = "", passFail = 0, inputError = false){
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
            logTest("Valve Open", 1);
        }
        //if it still thinks it's closed, the test fails
        else{
        	logTest("Valve Open", 0);
        }
    }
    //if there's an issue in the above test, it failed
    catch(error){
        logTest("Valve Open", 0, error);
    }
    //Test 2
    //testing closure of the valve, should be reflected in nv.valvestate
    //should succeed
    try{
        //close the valve, should be valid
        receiveInstructions({open = false , nextCheckIn = 0.1});
        //if the valve thinks it's valvestate is false, it passes
        if(!nv.valveState){
            logTest("Valve Close", 1);
        }
        //if it still thinks it's open, the test fails
        else{
            logTest("Valve Close", 0);
        }
    }
    //if there's an issue in the above test, it failed
    catch(error){
        logTest("Valve Close", 0, error);
    }
    //Test 3
    //trying receiveInstructions without an open value
    //should fail
    try{
        receiveInstructions({nextCheckIn = 0.1});
        //if receiveInstructions passes without error, the test fails
        logTest("receiveInstructions (not enough params, missing 'open')", 0);
    }
    //if there isn't an issue in the above test, it failed
    catch(error){
        logTest("receiveInstructions (not enough params, missing 'open')", 1, error);
    }
    //Test 4
    //trying receiveInstructions without a nextCheckIn value
    //should fail
    try{
        receiveInstructions({open = true});
        //if receiveInstructions passes without error, the test fails
        logTest("receiveInstructions (not enough params, missing 'nextCheckIn')", 0);
    }
    //if there isn't issue in the above test, it failed
    catch(error){
        logTest("receiveInstructions (not enough params, missing 'open')", 1, error);
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
        logTest("red LED tests", 1);
    }
    catch(error){
        logTest("red LED tests", 0, error);
    }
    //test 2
    //configuring blue LED, turning it on and off
    //should pass
    try{
        blueConfigure();
        blueOn();
        blueOff();
        logTest("blue LED tests", 1);
    }
    catch(error){
        logTest("blue LED tests", 0, error);
    }
    //test 3
    //configuring green LED, turning it on and off
    //should pass
    try{
        greenConfigure();
        greenOn();
        greenOff();
        logTest("green LED tests", 1);
    }
    catch(error){
        logTest("green LED tests", 0, error);
    }
}

//Testing the valve related functions
function testValve(){
    //test 1:
    //try the valvePinInit function
    //should pass
    try{
        valvePinInit();
        logTest("valve Pin Init", 1);
    }
    catch(error){
        logTest("valve Pin Init", 0, error);
    }
    //test 2:
    //try the valveConfigure function
    //should fail
    try{
        valveConfigure();
        logTest("valve configure", 1);
    }
    catch(error){
        logTest("valve Pin Init", 0, error);
    }
    //test 3:
    //try the open function, check the NV table
    //should pass, should have nv.valvestate equal to true
    try{
        open()
        if(nv.valveState==true){
        	logTest("valve open", 1);
        }
        else{
        	logTest("valve open", 0);
        }
    }
    catch(error){
        logTest("valve Pin Init", 0, error);
    }
    //test 4:
    //try the close function, check the NV table
    //should pass, should have nv.valvestate equal to false
    try{
        close();
        if(nv.valveState==false){
        	logTest("valve close", 1);
        }
        else{
        	logTest("valve close", 0);
        }
    }
    catch(error){
        logTest("valve close", 0, error);
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





