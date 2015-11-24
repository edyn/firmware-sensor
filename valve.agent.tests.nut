
firebaseAuthTemp <-"";
firebaseAuthTemp = firebaseAuth;
testsPassed <- [];
testsFailed <-[];

function sendDataFromDeviceTests(){

	//test 1: regular operation with dummy data inputs should succeed
	try{
		local result = sendDataFromDevice({dummyData : "Random Inputs Should Succeed"});
		if(result){
			server.log("sendDataFromDevice (random inputs) succeeded");
			testsPassed.append("sendDataFromDevice (random inputs) succeeded");
		}
		else{
			server.log("sendDataFromDevice (random inputs) failed");
			testsFailed.append("sendDataFromDevice (random inputs) failed")};
		}
	}
	catch(error){
		server.log("sendDataFromDevice (random inputs) failed");
		testsFailed.append("sendDataFromDevice (random inputs) failed (throws error)")};
	}
	//test 2: trying to send with invalid authorization should fail
	firebaseAuth <- "IncorrectAuth";
	try{
		local result = sendDataFromDevice({dummyData : "Random Inputs Should Succeed"});
		//(opposite of previous comment) Anything we send shoudl fail in this test because we are inputting a bad API key
		if(result != 200){
			server.log("Send Data From Device (bad API key) success");
			testsPassed.append("Send Data From Device (bad API key) success");
		}
		else{
			server.log("Send Data From Device (bad API key) failed, backend accepted bad authorization");
			testsFailed.append("Send Data From Device (bad API key) failed, backend accepted bad authorization");
		}
	}
	catch(error){
		server.log("Send Data From Device (bad API key) failed (throws error)");
		testsFailed.append("Send Data From Device (bad API key) failed (throws error)");
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
			server.log("Send Data From Device (Real Data) failed");
			testsFailed.append("Send Data From Device (Real Data) failed");
		}
		else{
			server.log("Send Data From Device (Real Data) Success");
			testsPassed.append("Send Data From Device (Real Data) Success");
		}
	}

	//still shouldn't throw an error, so this should be considered a failure in either case
	catch(error){
		server.log("Send Data From Device (Real Data) failed (throws error)");
		testsFailed.append("Send Data From Device (Real Data) failed (throws error)");
	}	
	firebaseAuth <- firebaseAuthTemp;
}

