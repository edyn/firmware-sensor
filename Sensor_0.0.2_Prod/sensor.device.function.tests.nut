//FUNCTIONAL TEST CODE BELOW THIS LINE


fakeWifi <- true;
fakeBattery <- 3.3;
mainRun <- 0;

function sendResults(){
	mute = false;
	server.log("LAST SLEEP: " + mostRecentDeepSleepCall + "\nWAKE REASON: " + wakeReason)
	if(nv.data.len()){
		server.log("STORED READINGS: " + nv.data.len());
	}
	if(nv.storedErrors.len()){
		server.log("STORED ERRORS: " + nv.storedErrors.len());
	}
	agent.send("deviceResults", {"mainRun" : mainRun, "lastSleep" : mostRecentDeepSleepCall,  "wakeReason" : wakeReason, "storedReadings" : nv.data.len()})
	if(nv.storedErrors.len()){
		for(local x = 0; x < nv.storedErrors.len(); x++){
			if("message" in nv.storedErrors[x]){
				server.log("message in stored error: " + nv.storedErrors[x].message)
			} else {
				server.log("no message in stored error #" + x)
			}
			if("error" in nv.storedErrors[x]){
				server.log("Error in stored error: " + nv.storedErrors[x].error)
			} else {
				server.log("no Error in stored error #" + x)
			}
		}
	}
	mute = true
}

agent.on("runMain", 
	function(runTable){
		fakeBattery = runTable.battery;
		fakeWifi = runTable.online;
		fakeTime = runTable.fakeTime;
		wakeReason = runTable.wakeReason;
		mute = runTable.mute;
		throwError = runTable.throwError;
		connectSuccess = runTable.connectSuccess;
		mainRun += 1;
		branchSelect = 0;
		serverConnectCalled = 0;
		mainWithSafety();
	}
)
