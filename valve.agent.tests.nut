
firebaseAuthTemp <- "";
firebaseAuthTemp = firebaseAuth;
testsPassed <- [];
testsFailed <-[];

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

function sendDataFromDeviceTests(){

    //test 1: regular operation with dummy data inputs should succeed
    try{
        local result = sendDataFromDevice({dummyData = "Random Inputs Should Succeed"});
        if(result){
            logTest("sendDataFromDevice (random inputs)", 1);
        }
        else{
            logTest("sendDataFromDevice (random inputs)", 0)
        }
    }
    catch(error){
        logTest("sendDataFromDevice (random inputs)", 0, error)
    }
    //test 2: trying to send with invalid authorization should fail
    firebaseAuth <- "IncorrectAuth";
    try{
        local result = sendDataFromDevice({dummyData = "Random Inputs Should Succeed"});
        //(opposite of previous comment) Anything we send shoudl fail in this test because we are inputting a bad API key
        if(result != 200){
            logTest("sendDataFromDevice (bad auth)", 1);
        }
        else{
        	logTest("sendDataFromDevice (bad auth)", 0);    
        }
    }
    catch(error){
        logTest("sendDataFromDevice (bad auth)", 0, error);
    }
    firebaseAuth <- firebaseAuthTemp;
    //same as last test but with regular data
    try{
        local result = sendDataFromDevice({
        macId = "20000c2a690a2e2b",
        wakereason = 1,
        batteryLevel = 3.3,
        solarLevel = 4.3,
        valveOpen = true,
        timestamp = date().time,
        rssi = -60,
        firmwareVersion = 0.1
        });
        //anything should work when new rules are implemented.
        if(result != 200){
            logTest("sendDataFromDevice (real data)", 0)
        }
        else{
            logTest("sendDataFromDevice (real data)", 1)
        }
    }

    //still shouldn't throw an error, so this should be considered a failure in either case
    catch(error){
    		logTest("sendDataFromDevice (real data)", 0, error)
    }    
}

sendDataFromDeviceTests();
imp.sleep(2);
server.log("\nAgent Tests Failed:");
server.log(testsFailed.len());
if(testsFailed.len()>0){
    server.log("\nSpecifically these tests:");
    for (local x = 0; x < testsFailed.len(); x++){
        server.log(testsFailed[x]);
    }
}
server.log("\n");

