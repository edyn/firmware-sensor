
firebaseAuthTemp <-"";
firebaseAuthTemp = firebaseAuth;

function sendDataFromDeviceTests(){
	local testPasses=[];
	//test 1: regular operation with dummy data inputs should succeed
	try{
		local result = sendDataFromDevice({dummyData : "Random Inputs Should Succeed"});
		if(result){
			testPasses.append(true);
		}
		else{
			testPasses.append(false);
		}
	}
	catch(error){
		testPasses.append(false);
	}
	//test 2: trying to send with invalid authorization should fail
	firebaseAuth <- "IncorrectAuth";
	try{
		local result = sendDataFromDevice({dummyData : "Random Inputs Should Succeed"});
		if(result){
			testPasses.append(false);
		}
		else{
			testPasses.append(true);
		}
	}
	//still shouldn't throw an error, so this should be considered a failure in either case
	catch(error){
		testPasses.append(false);
	}	
	firebaseAuth <- firebaseAuthTemp;
}