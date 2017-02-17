server.log("Device running functional tests")
//todo before release: add exponential error test

mainRunNumber <- 1;
scheduleFromBackend <- null
currentTestName <- "0"

//function that runs over and over, once for each event in a sequence:
function runMain(runTable){
	mainRunNumber += 1;
	server.log("\n\nMAIN RUN NUMBER: " + (mainRunNumber - 1))
	server.log(http.jsonencode({"wakeReason" : runTable.wakeReason, "online" : runTable.online, "battery" : runTable.battery, "fakeTime" : runTable.fakeTime, "mute" : runTable.mute}))
	device.send("runMain", {"wakeReason" : runTable.wakeReason, "online" : runTable.online, "battery" : runTable.battery, "fakeTime" : runTable.fakeTime, "mute" : runTable.mute, "throwError" : runTable.throwError});
}

//adding null as as first index so this table is 1 indexed
expectedResultsArray <- [null]
runMainSequenceArray <- [null]

//Tracks names to make debugging easier:
testName <- "Null"
testNameChangeArray <- {}

//wake reason constants not defined by eimp on agent (for no good reason) but it frees us up to create our own!
const WR_BOOT = 0;
const WR_TIMER = 1;
const WR_SW_RESET = 2;
const WR_BUTTON = 3;
const WR_NEW_SQUIRREL = 4;
const WR_SQUIRREL_ERROR = 5;
const WR_NEW_FW = 6;
const WR_BLINKUP = 9;
const WR_SW_RESTART = 10; //Planned addition in os 36, gotta get ready, yo

////////////////////////////////////////////////////////////////////////////////////////////////////
//this is where we lego together the sequence of events and the expected results after every event//
////////////////////////////////////////////////////////////////////////////////////////////////////

function createDeviceResults(lastSleep, wakeReason, storedReadings){
	return ({"lastSleep" : lastSleep, "wakeReason" : wakeReason, "storedReadings" : storedReadings});
}

function createSingleEvent(online, battery, wakeReason, fakeTime, throwError, mute){
	return ({"online" : online, "battery" : battery, "wakeReason" : wakeReason, "fakeTime" : fakeTime, "mute" : mute, "throwError" : throwError});
}

// an "event" is a single main run for the device
// a "watering" is a single schedule object as sent from the backend
// a single "device results" is some information from the device like how many stored readings it had
// a single "watering results" is the results that the agent would send to the backend during or after a watering (even if the watering didn't happen)
// a "checkIn" is all four of these being appended to their respective arrays
// a "sequence" is multiple "checkIn"s that form a narrative
//most time series will focus more or less around the time 2200, as it is 1000 + 1200 seconds (20 minutes)

jsonNull <- http.jsonencode([]);

function exampleSequence(){

	testNameChangeArray[runMainSequenceArray.len()] <- "exampleSequence"

	//Events
	/////////////////////////// 		Connected|   Battery| Wake Reason|      Fake Time|   Error| 	Mute|
	local eventA = createSingleEvent(		 true, 	 	3.31,    WR_TIMER, 		     2190, 	 false, 	true/*mute*/);

	//Device Results 
	////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
	local deviceResultsA = createDeviceResults(	   600,		WR_TIMER, 				0);
	
	//Sequence
	//////////////////

	//1 (r2)
	expectedResultsArray.append(deviceResultsA)
	runMainSequenceArray.append(eventA)
}

//Sequence 1
function connectedAndSendingData(){

	testNameChangeArray[runMainSequenceArray.len()] <- "connectedAndSendingData"

	//Events
	/////////////////////////// 		Connected|   Battery| Wake Reason|      Fake Time|   Error| 	Mute|
	local eventA = createSingleEvent(		 true, 	 	3.31,    WR_TIMER, 		     2190, 	 false, 	true/*mute*/);
	local eventB = createSingleEvent(		 true, 		3.31,    WR_TIMER, 		     2200, 	 false,		true/*mute*/);
	local eventC = createSingleEvent(		 true, 		3.31,    WR_TIMER, 			 2260, 	 false, 	true/*mute*/);
	local eventD = createSingleEvent(		 true, 		3.31,    WR_TIMER, 			 2740, 	 false, 	true/*mute*/);
	local eventE = createSingleEvent(		 true, 		3.31,    WR_TIMER, 			 2800, 	 false, 	true/*mute*/);
	local eventF = createSingleEvent(		 true, 		3.31,    WR_TIMER, 			 2860, 	 false, 	true/*mute*/);
	local eventG = createSingleEvent(		 true, 		3.31,    WR_TIMER, 			 2920, 	 false, 	true/*mute*/);
	local eventH = createSingleEvent(		 true, 		3.31,    WR_TIMER, 			 2980, 	 false, 	true/*mute*/);

	//Device Results 
	////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
	local deviceResultsA = createDeviceResults(	   600,		WR_TIMER, 				0);
	local deviceResultsB = createDeviceResults(	   600,		WR_TIMER, 				0);
	local deviceResultsC = createDeviceResults(	   600,		WR_TIMER, 				0);
	local deviceResultsD = createDeviceResults(	   600,		WR_TIMER, 				0);

	//Sequence
	//////////////////

	//1 (r2)
	expectedResultsArray.append(deviceResultsA)
	runMainSequenceArray.append(eventA)
	
	//2 (r3)
	expectedResultsArray.append(deviceResultsB)
	runMainSequenceArray.append(eventB)
	
	//3 (r4)
	expectedResultsArray.append(deviceResultsB)
	runMainSequenceArray.append(eventC)
	
	//4 (r5)
	expectedResultsArray.append(deviceResultsB)
	runMainSequenceArray.append(eventD)
	
	//5 (r6)
	expectedResultsArray.append(deviceResultsC)
	runMainSequenceArray.append(eventE)
	
	//6 (r7)
	expectedResultsArray.append(deviceResultsB)
	runMainSequenceArray.append(eventF)
	
	//7 (r8)
	expectedResultsArray.append(deviceResultsB)
	runMainSequenceArray.append(eventG)
	
	//8 (r9)
	expectedResultsArray.append(deviceResultsD)
	runMainSequenceArray.append(eventH)
	
}


successes <- []
failures <- []
function logResults(a = "a" , b = "b"){
	server.log("\n\n\n\n\n\n\n\nDone running all tests (here are some results)")
	local errors = expectedResultsArray.len() - 1 - (successes.len() + failures.len())
	server.log("Successes: " + successes.len())
	server.log("Failures: " + failures.len())
	server.log("Errors: " + errors)
	for(local z = 0; z < failures.len(); z++){
		server.log("\n FAILURE #" + z)
		server.log(failures[z])
	}
	imp.wakeup(10,logResults)
}

////////////////
//Run the loop//
////////////////

runDelay <- 15.0;
function runMainLoop(){
	if(mainRunNumber in testNameChangeArray){
		testName = testNameChangeArray[mainRunNumber];
	}
	if(mainRunNumber < runMainSequenceArray.len()){
		local nextRunTable = runMainSequenceArray[mainRunNumber];
		server.log ("\n\nRUNNING MAIN SEQUENCE " + mainRunNumber + "/" + (runMainSequenceArray.len()-1) +  "\nrunnining with parameters:\n" + "\nconnected: " + nextRunTable.online  + "\nbattery: " + nextRunTable.battery)
		runMain(nextRunTable)
	} else {
		logResults();	
	}
}
server.log("delaying start, clear the console!");
imp.sleep(3);

function processDeviceResults(results){
	server.log("DEVICE RESULTS:\n" + http.jsonencode(results))
	local mainIndex = results.mainRun;
	local failureString = ""
	local lastSleep = results.lastSleep;
	if("lastSleep" in expectedResultsArray[mainIndex]){
		//equals to
		if(expectedResultsArray[mainIndex].lastSleep != results.lastSleep){
			server.log("FAIL LAST SLEEP ON MAIN RUN " + mainIndex)
			failureString = failureString + testName + " fail lastSleep in event " + mainIndex + ", expected: " + expectedResultsArray[mainIndex].lastSleep + ", actual: " + results.lastSleep + "\n"
		}
	}
	if(results.wakeReason != expectedResultsArray[mainIndex].wakeReason){
		server.log("FAIL WAKE REASON ON MAIN RUN " + mainIndex)
		failureString = failureString + testName + " fail wakeReason in event " + mainIndex + ", expected: " + expectedResultsArray[mainIndex].wakeReason + ", actual: " + results.wakeReason+ "\n"
	}
	if(results.storedReadings < expectedResultsArray[mainIndex].storedReadings){
		server.log("FAIL stored readings ON MAIN RUN " + mainIndex)
		failureString = failureString + testName + " fail storedReadings in event " + mainIndex + ", expected at least: " + expectedResultsArray[mainIndex].storedReadings + ", actual: " + results.storedReadings+ "\n"
	}
	if(failureString.len()){
		server.log(failureString)
		failures.append(failureString)
	} else {
		server.log("\n\nEVENT " + mainIndex + " " + testName + " SUCCESS\n\n")
		successes.append(mainIndex)
	}
	imp.wakeup(1, runMainLoop);
}

device.on("deviceResults", processDeviceResults);

connectedDuringWateringSequence();

//Start running the tests:
runMainLoop();

http.onrequest(logResults)

device.on("jsonLog", function (data)  {
	server.log("JSON LOG:")
	server.log(http.jsonencode(data))
});













