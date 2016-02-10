const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);
unitTesting <- false;
const valveOpenMaxSleepTime = 1.0; //minutes
const valveCloseMaxSleepTime = 20.0;
const chargingPollAveraging = 15.0;
const hardwareVersion = "0.0.1";
const firmwareVersion = "0.0.1";
const batteryLow = 3.2;
const lowBatterySleepTime = 60 //minutes = 1 hour
const batteryCritical = 2.9;
const criticalBatterySleepTime = 6 * 60 //minutes = 6 hours
const receiveInstructionsWaitTimer = 30 //seconds, it could probably be MUCH lower
wakeReason <- hardware.wakereason();

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
if ( ! ("nv" in getroottable() && "valveState" in nv)) {
    nv <- {valveState = false, iteration = 0}; 
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
    imp.onidle(function() {
        server.sleepfor(inputTime);
    });
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

function receiveInstructions(instructions){
    server.log("received New Instructions");
    local sleepUntil = 0;
    server.log(instructions.open);
    server.log(instructions.nextCheckIn);
    server.log(instructions.iteration);
    local change = false;
    //if neither of the below statements 
    //TODO: battery check before opening

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
                deepSleepForTime(valveCloseMaxSleepTime * 60.0);
            }
            return
        }
    }
    catch(error){
        close();
        server.log("ERROR IN VALVE ITERATION CHECK! closing just in case. error is " + error);
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
        close();
        server.log("ERROR IN VALVE STATE CHANGE! closing just in case. error is " + error);
    }
    //If the valve changes state, let the backend know
    if(change == true){
        //TODO: change this to just take a second reading and send it instead
        agent.send("valveStateChange" , {valveOpen = nv.valveState});
    }
    //Check for valid times
    //TODO: check for type safety
    //TODO: check for negative values
    if(!unitTesting){
        //on blinkup, just sleep 5 minutes
        if(wakeReason == 9){
            deepSleepForTime(valveOpenMaxSleepTime * 60.0);
        }
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
}


function onConnectedCallback(state, dataToPass) {
    // If we're connected...
    if (state == SERVER_CONNECTED) {
        server.log("sendingData");
        sendData(dataToPass);
        if(dataToPass.batteryVoltage < batteryLow){
            if(nv.valveState == true){
                close();
            }
            //don't wait for more instructions, just go back to sleep
            deepSleepForTime(lowBatterySleepTime * 60.0);
            return
        } else {
            //not sure if agent.on works inside functions, but it should?
            agent.on("receiveInstructions", receiveInstructions);
            imp.wakeup(deepSleepForTime(valveCloseMaxSleepTime * 60.0), receiveInstructionsWaitTimer);
        }
    } 
    //if we're not connected...
    else {
        //Valve fails to connect:
        if(nv.valveState == true){
            close();
        }
        if(!unitTesting){
            deepSleepForTime(valveCloseMaxSleepTime * 60.0);
        }else{
            server.log("Simulated Disconnect")
            return false
        }
    }
}


function connect(callback, timeout, dataToPass) {
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

function main(){
    //This will only log if the imp is ALREADY connected:
    server.log("main")
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
        imp.sleep(90)
    }
    local dataTable = collectData();
    if(dataTable.batteryVoltage < batteryCritical){
        //HIGHLY unlikely, pretty much impossible:
        if(nv.valveState == true){
            close();
        }
        //valve battery is critical, don't even connect to wifi
        deepSleepForTime(criticalBatterySleepTime * 60.0);
        //return the main function; pretty much ensures imp.idle() required for deep sleep
        return
    } else {
        connect(onConnectedCallback , TIMEOUT_SERVER_S, dataTable);
    }
}
if(!unitTesting){
    main();
}

