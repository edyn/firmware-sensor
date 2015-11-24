testsPassed <- [];
testsFailed <- [];


//testing various inputs to the receiveInstructions() function
function receiveInstructionsTests(){
	//Test 1
	//testing the opening of the valve, should succeed
	//should succeed
	try{
		//open the valve, should be valid
		receiveInstructions(instructions={open : true , nextCheckIn = 0.1})
		//if the valve thinks it's valvestate is true, it passes
		if(nv.valveState){
			server.log("Valve Open Test Passed");
			testsPassed.append("Valve Open Test Passed");
		}
		//if it still thinks it's closed, the test fails
		else{
			server.log("Valve Open Test Failed");
			testsFailed.append("Valve Open Test Failed");
		}
	}
	//if there's an issue in the above test, it failed
	catch(error){
		server.log("Valve Open Test Failed");
		testsFailed.append("Valve Open Test Failed (throws error)");
	}
	//Test 2
	//testing closure of the valve, should be reflected in nv.valvestate
	//should succeed
	try{
		//close the valve, should be valid
		receiveInstructions(instructions={open : false , nextCheckIn = 0.1})
		//if the valve thinks it's valvestate is false, it passes
		if(!nv.valveState){
			server.log("Valve Close Test Passed");
			testsPassed.append("Valve Closure Test Passed");
		}
		//if it still thinks it's open, the test fails
		else{
			server.log("Valve Close Test Failed");
			testsFailed.append("Valve Close Test Failed");
		}
	}
	//if there's an issue in the above test, it failed
	catch(error){
		server.log("Valve Close Test Failed");
		testsFailed.append("Valve Close Test Failed (throws error)");
	}
	//Test 3
	//trying receiveInstructions without an open value
	//should fail
	try{
		receiveInstructions(instructions={nextCheckIn = 0.1})
		//if receiveInstructions passes without error, the test fails
		server.log("Receive Instructions (not enough parameters, missing valveState) Test Failed");
		testsFailed.append("Receive Instructions (not enough parameters, missing valveState) Test Failed");
	}
	//if there isn't an issue in the above test, it failed
	catch(error){
		server.log("Receive Instructions (not enough parameters, missing valveState) Test Success (throws error)");
		testsPassed.append("Receive Instructions (not enough parameters, missing ValveState) Test Success (throws error)");
	}
	//Test 4
	//trying receiveInstructions without a nextCheckIn value
	//should fail
	try{
		receiveInstructions(instructions={open : true})
		//if receiveInstructions passes without error, the test fails
		server.log("Receive Instructions (not enough parameters, missing nextCheckIn) Test Success (throws error)");
		testsFailed.append("Receive Instructions (not enough parameters, missing nextChecIn) Test Success (throws error)");
	
	}
	//if there isn't issue in the above test, it failed
	catch(error){
		server.log("Receive Instructions (not enough parameters, missing nextCheckIn) Test Failed (throws error)");
		testsPassed.append("Receive Instructions (not enough parameters, missing nextCheckIn) Test Success (throws error)");
	}
}

//Testing the LED related functions
function testLEDs(){
	//test 1
	//configuring red LED, turning it on and off
	//should pass
	try{
		redConfigure()
		redOn()
		redOff()
		server.log("Red LED tests Passed");
		testsPassed.append("Red LED tests Passed");
	}
	catch(error){
		server.log("Red LED tests Failed (Throws Error)");
		testsFailed.append("red LED tests failed (Throws Error)");
	}
	//test 2
	//configuring blue LED, turning it on and off
	//should pass
	try{
		blueConfigure()
		blueOn()
		blueOff()
		server.log("blue LED tests Passed");
		testsPassed.append("blue LED tests Passed");
	}
	catch(error){
		server.log("blue LED tests Failed (Throws Error)");
		testsFailed.append("blue LED tests failed (Throws Error)");
	}
	//test 3
	//configuring green LED, turning it on and off
	//should pass
	try{
		greenConfigure()
		greenOn()
		greenOff()
		server.log("green LED tests Passed");
		testsPassed.append("green LED tests Passed");
	}
	catch(error){
		server.log("green LED tests Failed (throws error)");
		testsFailed.append("green LED tests Failed (throws error)");
	}
}

//Testing the valve related functions
function testValve(){
	testPasses=[]
	//test 1:
	//try the valvePinInit function
	//should pass
	try{
		valvePinInit()
		server.log("Valve Pin Init Passed");
		testsPassed.append("Valve Pin Init Passed");
	}
	catch(error){
		server.log("Valve Pin Init Failed");
		testsFailed.append("Valve Pin Init Failed");
	}
	//test 2:
	//try the valveConfigure function
	//should fail
	try{
		valveConfigure()
		server.log("Valve Configure Passed");
		testsPassed.append("Valve Configure Passed");
	}
	catch(error){
		server.log("Valve Pin Init Failed");
		testsFailed.append("Valve Configure Failed");
	}
	//test 3:
	//try the open function, check the NV table
	//should pass, should have nv.valvestate equal to true
	try{
		open()
		if(nv.valveState==true){
			server.log("Valve Open Function Passed");
			testsPassed.append("Valve Open Function Passed");
		}
		else{
			server.log("Valve Open Function Failed");
			testsFailed.append("Valve Open Function Failed");
		}
	}
	catch(error){
			server.log("Valve Open Function Failed (throws error)");
			testsFailed.append("Valve Open Function Failed (throws error)");
	}
	//test 4:
	//try the close function, check the NV table
	//should pass, should have nv.valvestate equal to false
	try{
		close()
		if(nv.valveState==false){
			server.log("Valve Close Function Passed");
			testsPassed.append("Valve Close Function Passed");
		}
		else{
			server.log("Valve Close Function Failed");
			testsPassed.append("Valve Close Function Failed");
		}
	}
	catch(error){
		server.log("Valve Close Function Failed");
		testsPassed.append("Valve Close Function Failed (throws error)");
	}
}








