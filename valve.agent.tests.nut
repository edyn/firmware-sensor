
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
		//anything should work, so we're expecting 200, but if we tighten the rules in the future we might have to change this test
		if(result != 200){
			testPasses.append(false);
			server.log("Test Failed")
		}
		else{
			testPasses.append(true);
		}
	}
	//same as last test but with regular data
	try{
		local result = sendDataFromDevice({        
		"macId" : "20000c2a690a2e2b",
        "wakereason" : 1,
        "batteryLevel" = 3.3,
        "solarLevel" = 4.3,
        "valveOpen" = true,
        "timestamp" = date().time,
        "rssi" = -60,
        "firmwareVersion"=0.1
        });
		//anything should work when new rules are implemented.
		if(result != 200){
			testPasses.append(false);
			server.log("Test Failed")
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

