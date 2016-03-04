const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);
unitTesting <- false;
const errorSleepTime = 20.0; //minutes (arbitrary)
const logglyConnectTimeout = 20.0; //seconds
const responsiveTimer = 1200.0; // 1200 seconds = 20 minutes
const sleepOnErrorTime = 3600.0;
const valveOpenMaxSleepTime = 1.0; //minutes
const valveCloseMaxSleepTime = 20.0;
const chargingPollAveraging = 15.0;
const hardwareVersion = "0.0.1";
const firmwareVersion = "0.0.1";
const batteryLow = 3.2;
const lowBatterySleepTime = 60 //minutes = 1 hour
const batteryCritical = 2.9;
const criticalBatterySleepTime = 360; 
const receiveInstructionsWaitTimer = 30; 
wakeReason <- hardware.wakereason();
mostRecentDeepSleepCall <- 0;
macAddress <- imp.getmacaddress();
blinkupTimer <- 90;
watchDogTimeOut <- 130; //Equals 90 second blinkup + 30 second connect + 10 seconds of whatever else
watchDogSleepTime <- 20.0;//arbitrarily chosen to be 20 minutes
/**************
Valve Functions
***************/


function valvePinInit(){
    //Sets the pins to readable global variables
    //ToDo:
    //Function is done? Roll into valve configure function?
    controlPin <- hardware.pinE;
    forwardPin <- hardware.pin8;
    reversePin <- hardware.pin9;
}

function valveConfigure() {
    //configure valve pins and set initial state
    //ToDo:
    //Might add a close valve inside this function
    //Function is done?

    controlPin.configure(DIGITAL_OUT);
    forwardPin.configure(DIGITAL_OUT);
    reversePin.configure(DIGITAL_OUT);
    controlPin.write(0);
    forwardPin.write(0);
    reversePin.write(0);
}
    
function open() {
    //Opens the valve
    //ToDo:
    //add valve NV status update

    forwardPin.write(1);
    controlPin.write(1);
    imp.sleep(0.002); // 2ms
    forwardPin.write(1);
    imp.sleep(0.050); // 50ms
    forwardPin.write(0);
    controlPin.write(0);
    nv.valveState=true;
}

function close() {
    //Closes the valve
    //ToDo:
    //add valve NV status update

    reversePin.write(1);
    controlPin.write(1);
    imp.sleep(0.002); // 2ms
    reversePin.write(1);
    imp.sleep(0.050); // 50ms
    reversePin.write(0);
    controlPin.write(0);
    nv.valveState=false;
}

//This is run BEFORE main loop, right after declaring the close function for safety.
//we want to try to close the valve on any cold boot.
//wakeTime is for relevant waketimes; blinkup, cold boot, new os, new firmware
if ( ! ("nv" in getroottable() && "valveState" in nv)) {
    nv <- {valveState = false, iteration = 0, wakeTime = time()}; 
    valvePinInit();
    valveConfigure();
    close();
}

//WakeReason Function

function onWakeup(){
    local branching=0;
    switch(wakeReason){
        //branching = 0 cases:
        //if branching is 0, the device will:
        //close the valve
        //enter blinkup mode
        case WAKEREASON_POWER_ON: 
            branching=0;
            break
        case WAKEREASON_SW_RESET:
            branching=0;
            break
        case WAKEREASON_SQUIRREL_ERROR:
            branching=0;
            break
        case WAKEREASON_PIN1:
            branching=0;
            break    
        //branching 1 means the device can skip it's previous modes

        //This should skip the blinkup period
        case WAKEREASON_TIMER:
            branching=1;
            break
        case WAKEREASON_BLINKUP:
            branching=1;
            break
        case WAKEREASON_NEW_SQUIRREL:
            branching=1;
            break
        case WAKEREASON_NEW_FIRMWARE:
            branching=1;
            break
        //unlikely/impossible cases, but still 1
        case WAKEREASON_SNOOZE:
            branching=1;
            break
        case WAKEREASON_HW_RESET:
            branching=1;
            break
        //Below this should NEVER happen, but is there to be safe
        case null:
            branching=1
            server.log("Bad Wakereason");
            break
    }//endswitch
    return branching
}

function convertToVoltage(inputVoltage){
    local sysVol = hardware.voltage();
    local conversion = sysVol / 65535.0;
    local outputVoltage = inputVoltage * conversion;
    return outputVoltage
}

function chargingConfigure(){
    //Battery
    hardware.pinB.configure(ANALOG_IN);
    //Solar
    hardware.pin7.configure(ANALOG_IN);
    //nBatCharge
    //TODO: figure out what nBAT is for
    hardware.pin6.configure(DIGITAL_IN);
    //Charge Current
    //Need to figure out conversion of voltage to current
    hardware.pin5.configure(ANALOG_IN);
    //Charging Sign Pin
    //tells us if the battery is net charging or discharging
    hardware.pinA.configure(DIGITAL_IN);
}

function getBatteryVoltage(){
    local batReading = 0.0;
    batReading = hardware.pinB.read();
    batReading = convertToVoltage(batReading);
    batReading = batReading * 2.0;
    return batReading
}

function getChargeSign(){
    local chargeSignReading = 0;
    chargeSignReading = hardware.pinA.read();
    if(chargeSignReading == 0){
        return -1.0
    } else {
        return 1.0
    }
}

function getChargeCurrent(){
    //using "ampreading" instead of "currentReading" because of confusing homonym
    local ampReading = hardware.pin5.read();
    local chargeSign = getChargeSign();
    ampReading = convertToVoltage(ampReading);
    //conversion is ~ 1 volt = 0.48 amps, the readings on this pin tend towards 0.08 volts MAXIMUM
    ampReading = ampReading * chargeSign * 0.48;
    return ampReading
}

function getSolarVoltage(){
    local solarReading = hardware.pin7.read();
    solarReading = convertToVoltage(solarReading);
    solarReading = solarReading * 3.0;
    return solarReading
}

function getChargingStatus(){
    local batterySum = 0.0;
    local solarSum = 0.0;
    local chargeCurrentSum = 0.0;
    local batteryReadingAverage = 0.0;
    local solarReadingAverage = 0.0;
    local chargeCurrentAverage = 0.0;
    //There is a small delay within the loop. 
    //Time to execute a battery reading scales significantly and linearly with # of readings averaged
    for (local x=0; x<chargingPollAveraging; x++){
        batterySum += getBatteryVoltage();
        solarSum += getSolarVoltage();
        chargeCurrentSum += getChargeCurrent();
        imp.sleep(0.02);
    }
    batteryReadingAverage = batterySum / chargingPollAveraging;
    solarReadingAverage = solarSum / chargingPollAveraging;
    chargeCurrentAverage = chargeCurrentSum / chargingPollAveraging;
    return {battery = batteryReadingAverage, solar = solarReadingAverage, amperage = chargeCurrentAverage}
}

function forcedLogglyConnect(state, logTable, logLevel){
    // If we're connected...
    if (state == SERVER_CONNECTED) {
        agent.send(logLevel, logTable);
        return
    } 
    //if we're not connected...
    else {
        //Valve fails to connect:
        if(nv.valveState == true){
            close();
        }
        deepSleepForTime(valveCloseMaxSleepTime * 60.0);
        return
    }
}

function logglyLog(logTable = {}, forceConnect = false){
    if(server.isConnected()){
        agent.send("logglyLog", logTable)
    } else if(forceConnect){
        //connect and send loggly stuff
        //really no reason we'd ever force a connect for a regular log...
        server.connect(function (connectStatus){
            forcedLogglyConnect(connectStatus, logTable, "logglyLog");
        }, logglyConnectTimeout);
    }
}

function logglyWarn(logTable = {}, forceConnect = false){
    if(server.isConnected()){
        agent.send("logglyWarn", logTable)
    } else if(forceConnect){
        //connect and send loggly stuff
        server.connect(function (connectStatus){
            forcedLogglyConnect(connectStatus, logTable, "logglyWarn");
        }, logglyConnectTimeout);
    }
}

function logglyError(logTable = {}, forceConnect = false){
    if(server.isConnected()){
        agent.send("logglyError", logTable)
    } else if(forceConnect){
        //connect and send loggly stuff
        server.connect(function (connectStatus){
            forcedLogglyConnect(connectStatus, logTable, "logglyError");
        }, logglyConnectTimeout);
    }
}

//Red Led Functions
function redConfigure(){
    hardware.pin2.configure(DIGITAL_OUT);
}

function redOn(){
    hardware.pin2.write(0);
}

function redOff(){
    hardware.pin2.write(1);
}

//Blue Led Functions
function blueConfigure(){
    hardware.pinC.configure(DIGITAL_OUT);
}

function blueOn(){
    hardware.pinC.write(0);
}

function blueOff(){
    hardware.pinC.write(1);
}

//Green Led Functions
function greenConfigure(){
    hardware.pinD.configure(DIGITAL_OUT);
}

function greenOn(){
    hardware.pinD.write(0);
}

function greenOff(){
    hardware.pinD.write(1);
}

/************************
device-side API functions
************************/

//function to simplify our deep sleep calls
function deepSleepForTime(inputTime){
    //TODO: add some robust error handling to this function in particular
    try{
        if(!unitTesting){
            imp.onidle(function() {
                server.sleepfor(inputTime);
            });
        } else {
            mostRecentDeepSleepCall = inputTime;
        }
    } catch(error) {        
        if(nv.valveState){
            close();
        }
        logglyError({
            "error" : error,
            "function" : "deepSleepForTime",
            "message" : "BAD error, deepsleepfortime has a bug!"
        });
        //this should be less dependent on external variables
        imp.onidle(function() {
            server.sleepfor(1200);
        });
        return
    }
}

function collectData(){
    //TODO: add directly to chargingtable instead of having two tables combine
    local dataTable = {};
    local chargingTable = getChargingStatus();
    dataTable.wakeReason <- hardware.wakereason();
    dataTable.batteryVoltage <- chargingTable.battery;
    dataTable.solarVoltage <- chargingTable.solar;
    dataTable.amperage <- chargingTable.amperage;
    dataTable.valveState <- nv.valveState;
    dataTable.timestamp <- date().time;
    dataTable.rssi <- imp.rssi();
    dataTable.OSVersion <- imp.getsoftwareversion();
    dataTable.hardwareVersion <-hardwareVersion;
    dataTable.firmwareVersion <- firmwareVersion;
    return dataTable
}

//Send data to agent
function sendData(dataToSend){
    agent.send("sendData", dataToSend);
}

function disobey(message, dataToPass){
    try{
        server.log("disobeying because " + message);
        dataToPass.disobeyReason <- message;
        sendData(dataToPass);
    } catch (error){        
        if(nv.valveState){
            close();
        }
        logglyError({
            "error" : error,
            "function" : "disobey",
            "message" : "BAD error, disobey has a bug!"
        })
        server.log("Error in disobey: " + error);
    }
}

function minimum(a,b){
    if(a < b){
        return a
    } else{
        return b
    }
}

function receiveInstructions(instructions, dataToPass){
    server.log("received New Instructions");
    local sleepUntil = 0;
    server.log(instructions.open);
    server.log(instructions.nextCheckIn);
    server.log(instructions.iteration);
    local change = false;
    local sleepMinimum = minimum(valveOpenMaxSleepTime,instructions.nextCheckIn);
    //if neither of the below statements 
    //TODO: battery check before opening
    try{
        switch(wakeReason){

            /////////////////////////////////////////
            //disobey opens, deep sleep for minimum//
            /////////////////////////////////////////
            //Cold boot, button press, blinkup

            //coldboot
            case WAKEREASON_POWER_ON: 
                nv.iteration = instructions.iteration;
                if(instructions.open == true){
                    //disobey does nothing right now
                    disobey("Not opening because of cold boot", dataToPass);
                }
                deepSleepForTime(sleepMinimum * 60.0);
                return
                //break for good measure?
                break
            //button press; same as cold boot except you should also note the time:
            case WAKEREASON_PIN1:                
                nv.iteration = instructions.iteration;
                nv.wakeTime = time();
                if(instructions.open == true){
                    //disobey does nothing right now
                    disobey("Not opening because of button press", dataToPass);
                }
                deepSleepForTime(sleepMinimum * 60.0);
                return
                break    
            //blinkup same as cold boot
            case WAKEREASON_BLINKUP:
                nv.iteration = instructions.iteration;
                if(instructions.open == true){
                    //disobey does nothing right now
                    disobey("Not opening because of blinkup", dataToPass);
                }
                deepSleepForTime(sleepMinimum * 60.0);
                return
                break

            ////////////////////
            //Normal Operation//
            ////////////////////
            //Wake from timer, OS update, firmware update

            case WAKEREASON_TIMER:
                break
            case WAKEREASON_NEW_SQUIRREL:
                break
            case WAKEREASON_NEW_FIRMWARE:
                break

            /////////////////////////////
            //unlikely/impossible cases//
            /////////////////////////////
            //snooze, hardware reset, software reset, squirrel error, null
            //behave normally? I guess?
            //TODO: add loggly to ALL of these:

            case WAKEREASON_SNOOZE:
                break
            case WAKEREASON_HW_RESET:
                break
            case WAKEREASON_SW_RESET:
                break
            //This should be dealt with MUCH earlier, but in case it slipped through:
            case WAKEREASON_SQUIRREL_ERROR:
                nv.iteration = iteration;
                //sleep for an hour
                deepSleepForTime(sleepOnErrorTime);
                return
                break
            //Below this should NEVER happen, but is there to be safe
            case null:
                server.log("Bad Wakereason");
                break
            //deafult to behave normally
            default:
                break
        }
    } catch(error) {
        //TODO: make sure this is handled how we want:
        if(nv.valveState){
            close();
        }
        logglyError({
            "error" : error,
            "function" : "receiveInstructions (wakereason switch)",
            "message" : "something in the wake reason switching behavior is failing"
        });
        deepSleepForTime(sleepOnErrorTime);
        return
    }

    //check iterator vs instructions.iteration if instructions tell it to open but the iterator is frozen, don't open

    try{
        if(instructions.open == true && nv.iteration >= instructions.iteration){
            //This is embedded within the above if statement to prevent redundant close()s
            if(nv.valveState == true){
                agent.send("valveStateChange" , {valveOpen = false});
                close();
                server.log("Valve Closing Due to Iteration Failure");
            }
            server.log("Not opening due to iteration error.")
            if(!unitTesting){
                if(time() - nv.wakeTime < responsiveTimer){
                    deepSleepForTime(sleepMinimum * 60.0);
                } else{
                    deepSleepForTime(valveCloseMaxSleepTime * 60.0);   
                }
            }
            return
        }
    }
    catch(error){
        if(nv.valveState){
            close();
        }
        logglyError({
            "error" : error,
            "function" : "receiveInstructions (iteration check)",
            "message" : "something in the iteration checking logic is bugged"
        });
        server.log("ERROR IN VALVE ITERATION CHECK! closing just in case. error is " + error);
        deepSleepForTime(valveCloseMaxSleepTime * 60.0);
        return 
    }
    
    //Keep nv iteration current with what the backend thinks the iteration is:
    nv.iteration = instructions.iteration;
    //Valve State Changing
    try{
        //if valve is open and instructions say to close
        if(instructions.open == true && nv.valveState == false){
            //sleep to ensure we don't open/close valve too quickly
            imp.sleep(0.5);
            agent.send("valveStateChange" , {valveOpen = true});
            open();
            change = true;
            server.log("opening Valve");
        }
        //or valve is closed and instructions say to open
        else if (instructions.open == false && nv.valveState == true){
            imp.sleep(0.5);
            agent.send("valveStateChange" , {valveOpen = false});
            close();
            change = true;
            server.log("closing valve");
        }
    }
    catch(error){
        if(nv.valveState){
            close();
        }
        logglyError({
            "error" : error,
            "function" : "receiveInstructions (process instructions)",
            "message" : "ERROR IN VALVE STATE CHANGE! closing just in case."
        });
        server.log("ERROR IN VALVE STATE CHANGE! closing just in case. error is " + error);
        deepSleepForTime(errorSleepTime * 60.0);
        return
    }
    try{
        //If the valve changes state, let the backend know
        if(change == true){
            //TODO: change this to just take a second reading and send it instead
            agent.send("valveStateChange" , {valveOpen = nv.valveState});
        }
        //if it's still in the 'responsive' timer state, sleep for sleepminimum
        //regardless of valve state
        if(time() - nv.wakeTime < responsiveTimer){
            deepSleepForTime(sleepMinimum * 60.0);
            return
        }
        //Check for valid times
        //TODO: check for type safety
        //TODO: check for negative values
        if(!unitTesting){
            if(nv.valveState == true){
                //do not allow the valve to accept times greater than defaults:
                if(instructions.nextCheckIn > valveOpenMaxSleepTime){
                    deepSleepForTime(valveOpenMaxSleepTime * 60.0);
                    return 
                }
                //The next check in time is valid:
                else{
                    deepSleepForTime(instructions.nextCheckIn * 60.0);
                    return 
                }
            }
            //Closed Case:
            else if(nv.valveState == false){
                //do not allow the valve to accept times greater than defaults:
                if(instructions.nextCheckIn > valveCloseMaxSleepTime){
                    deepSleepForTime(valveCloseMaxSleepTime * 60.0);
                    return 
                }
                //The next check in time is valid:
                else{
                    deepSleepForTime(instructions.nextCheckIn * 60.0);
                    return 
                }
            }
            //this should NEVER occur, but is here for safety's sake
            deepSleepForTime(valveOpenMaxSleepTime * 60.0);
        }
    } catch(error) {
        if(nv.valveState){
            close();
        }
        logglyError({
            "error" : error,
            "function" : "receiveInstructions (sleep determination)",
            "message" : "the logic to determine if the valve for sleep or not is throwing an error"
        });
        deepSleepForTime(errorSleepTime * 60.0);
        return
    }
}

function batteryLowCheck(dataToPass){
    if(dataToPass.batteryVoltage < batteryLow){
        //if the battery is low and valve is open, close the valve
        if(nv.valveState == true){
             close();
        }
        disobey("Not opening because of low battery", dataToPass);
        return false
    } else {
        return true
    }
}

function onConnectedCallback(state, dataToPass) {
    // If we're connected...
    if (state == SERVER_CONNECTED) {
        if(batteryLowCheck(dataToPass)){
            //TODO: No asynchronous functions inside synchronous-appearing functions allowed.
            //not sure if agent.on works inside functions, but it should?
            agent.on("receiveInstructions", function(instructions){receiveInstructions(instructions, dataToPass)});
            //The below statement works as a "timeout" for receive instructions
            imp.wakeup(receiveInstructionsWaitTimer, function(){deepSleepForTime(valveCloseMaxSleepTime * 60.0)});
        } else{
            //don't wait for more instructions, just go back to sleep
            deepSleepForTime(lowBatterySleepTime * 60.0);
        }
        server.log("sendingData");
        sendData(dataToPass);
    } 
    //if we're not connected...
    else {
        //Valve fails to connect:
        if(nv.valveState == true){
            close();
        }
        deepSleepForTime(valveCloseMaxSleepTime * 60.0);
        return
    }
}


function connectAndSend(callback, timeout, dataToPass) {
    // Check if we're connected before calling server.connect()
    // to avoid race condition
    if (server.isconnected()) {
        // We're already connected, so execute the callback
        callback(SERVER_CONNECTED, dataToPass);
    } 
    else {
        // Otherwise, proceed as normal
        server.connect(function (connectStatus){
            callback(connectStatus, dataToPass)
        }, timeout);
    }
}

function batteryCriticalCheck(dataTable){
    if(dataTable.batteryVoltage < batteryCritical){
        //HIGHLY unlikely, pretty much impossible:
        if(nv.valveState == true){
            close();
        }
        //return the main function; pretty much ensures imp.idle() required for deep sleep
        return false
    } else {
        return true
    }
}


function main(){
    //This will only log if the imp is ALREADY connected:
    server.log("main")
    try{
        imp.enableblinkup(true)
        blueConfigure();
        blueOn();
        redConfigure();
        redOn();
        greenConfigure();
        greenOn();
        chargingConfigure();
        valvePinInit();
        valveConfigure();
        hardware.pin1.configure(DIGITAL_IN_WAKEUP, function(){
            if(nv.valveState == true){
                close();
            }
        });
        //If onWakeup() returns 0, go into 'blinkup phase' 
        if(!onWakeup()){
            close()
            imp.sleep(blinkupTimer)
        }
        local dataTable = collectData();
        //it's worth it for us to know battery level on these wakereasons
        //they all connect to wifi before doing anything else anyways
        if(batteryCriticalCheck(dataTable) || wakeReason == WAKEREASON_BLINKUP || wakeReason == WAKEREASON_NEW_FIRMWARE || wakeReason == WAKEREASON_POWER_ON){
            connectAndSend(onConnectedCallback , TIMEOUT_SERVER_S, dataTable);
        } else {
            //valve battery is critical, don't even connect to wifi
            deepSleepForTime(criticalBatterySleepTime * 60.0);
        }
    //This actually catches a huge amount of potential errors because it covers connectAndSend:
    } catch(error) {
        //This will need to have a forced connect:
        if(nv.valveState){
            close();
        }
        logglyError({
            "error" : error,
            "function" : "initializations and connect",
            "message" : "INITIALIZATION ERROR! HIGHEST PRIORITY FIX"
        }, true); //this 'true' is to enable force connect
        //TODO: this error case can force a connect regardless of battery critical state, you might want to change this in the future!!!
        deepSleepForTime(criticalBatterySleepTime * 60.0);
        //return from main pretty much guarantees that it will go to sleep right away
        return
    }
}

function softwareWatchdogTimer(){
    if(server.isconnected()){
        //TODO: make this loggly:
        server.log("WATCHDOG TIMER TOOK OVER! SOMETHING WENT BAD!")
    }
    deepSleepForTime(watchDogSleepTime * 60.0);
    return
}

if(!unitTesting){
    imp.wakeup(watchDogTimeOut, softwareWatchdogTimer);
    main();
}
