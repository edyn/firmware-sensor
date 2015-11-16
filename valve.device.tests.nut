
//testing various inputs to the receiveInstructions() function
function receiveInstructionsTests(){
	testPasses=[]
	//Test 1
	//testing the opening of the valve, should succeed
	//should succeed
	try{
		//open the valve, should be valid
		receiveInstructions(instructions={open : true , nextCheckIn = 0.1})
		//if the valve thinks it's valvestate is true, it passes
		if(nv.valveState){
			testPasses.append(true)
		}
		//if it still thinks it's closed, the test fails
		else{
			testPasses.append(false)
		}
	}
	//if there's an issue in the above test, it failed
	catch(error){
		testPasses.append(false)
	}
	//Test 2
	//testing closure of the valve, should be reflected in nv.valvestate
	//should succeed
	try{
		//close the valve, should be valid
		receiveInstructions(instructions={open : false , nextCheckIn = 0.1})
		//if the valve thinks it's valvestate is false, it passes
		if(!nv.valveState){
			testPasses.append(true)
		}
		//if it still thinks it's open, the test fails
		else{
			testPasses.append(false)
		}
	}
	//if there's an issue in the above test, it failed
	catch(error){
		testPasses.append(false)
	}
	//Test 3
	//trying receiveInstructions without an open value
	//should fail
	try{
		receiveInstructions(instructions={nextCheckIn = 0.1})
		//if receiveInstructions passes without error, the test fails
		testPasses.append(false)
	}
	//if there isn't an issue in the above test, it failed
	catch(error){
		testPasses.append(true)
	}
	//Test 4
	//trying receiveInstructions without a nextCheckIn value
	//should fail
	try{
		receiveInstructions(instructions={open : true})
		//if receiveInstructions passes without error, the test fails
		testPasses.append(false)
	}
	//if there isn't issue in the above test, it failed
	catch(error){
		testPasses.append(true)
	}
	return testPasses
}

//Testing the LED related functions
function testLEDs(){
	testPasses=[]
	//test 1
	//configuring red LED, turning it on and off
	//should pass
	try{
		redConfigure()
		redOn()
		redOff()
		testPasses.append(true)
	}
	catch(error){
		testPasses.append(false)
	}
	//test 2
	//configuring blue LED, turning it on and off
	//should pass
	try{
		blueConfigure()
		blueOn()
		blueOff()
		testPasses.append(true)
	}
	catch(error){
		testPasses.append(false)
	}
	//test 3
	//configuring green LED, turning it on and off
	//should pass
	try{
		greenConfigure()
		greenOn()
		greenOff()
		testPasses.append(true)
	}
	catch(error){
		testPasses.append(false)
	}
	return testPasses
}

//Testing the valve related functions
function testValve(){
	testPasses=[]
	//test 1:
	//try the valvePinInit function
	//should pass
	try{
		valvePinInit()
		testPasses.append(true)
	}
	catch(error){
		testPasses.append(false)
	}
	//test 2:
	//try the valveConfigure function
	//should fail
	try{
		valveConfigure()
		testPasses.append(true)
	}
	catch(error){
		testPasses.append(false)
	}
	//test 3:
	//try the open function, check the NV table
	//should pass, should have nv.valvestate equal to true
	try{
		open()
		if(nv.valveState==true){
			testPasses.append(true)
		}
		else{
			testPasses.append(false)
		}
	}
	catch(error){
		testPasses.append(false)
	}
	//test 4:
	//try the close function, check the NV table
	//should pass, should have nv.valvestate equal to false
	try{
		close()
		if(nv.valveState==false){
			testPasses.append(true)
		}
		else{
			testPasses.append(false)
		}
	}
	catch(error){
		testPasses.append(false)
	}
	return testPasses
}

server.log(receiveInstructionTests())
server.log(testLEDs())
server.log(testValve())







