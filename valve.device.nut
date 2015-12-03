const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);
unitTesting <- false;
const valveOpenMaxSleepTime = 1.0; //minutes
const valveCloseMaxSleepTime = 20.0;
const batteryAveraging = 15.0;

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
    nv <- {valveState = false}; 
    valvePinInit();
    valveConfigure();
    close();
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
    //Not really sure why this is useful...
    hardware.pin6.configure(DIGITAL_IN);
    //Charge Current
    //Need to figure out conversion of voltage to current
    hardware.pin5.configure(ANALOG_IN);
    //Charging Sign Pin
    //tells us if the battery is net charging or discharging
    hardware.pinA.configure(DIGITAL_IN);
}

function getBatteryVoltage(){
    local batterySum = 0.0;
    local tempReading = 0;
    local batteryReadingAverage = 0.0;
    //There is a small delay within the loop. 
    //Time to execute a battery reading scales significantly and linearly with # of readings averaged
    for (local x=0;x<batteryAveraging;x++){
        tempReading = hardware.pinB.read();
        tempReading = convertToVoltage(tempReading);
        tempReading = tempReading * 2.0;
        batterySum += tempReading;
        imp.sleep(0.02);
    }
    batteryReadingAverage = batterySum / batteryAveraging;
    return batteryReadingAverage
}

function getChargeCurrent(){
    //using "ampreading" instead of "currentReading" because of confusing homonym
    local ampReading = hardware.pin5.read();
    ampReading = convertToVoltage(ampReading);
    return ampReading
}

function getSolarVoltage(){
    local solarReading = hardware.pin7.read();
    solarReading = convertToVoltage(solarReading);
    solarReading = solarReading * 3.0;
    return solarReading
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

//Send data to agent
//dummy values currently in use
//these lines intentionally don't have semicolons
function sendData(){
    agent.send("sendData", {
        macId = imp.getmacaddress(),
        wakereason = hardware.wakereason(),
        batteryLevel = getBatteryVoltage(),
        solarLevel = getSolarVoltage(),
        amperage = getChargeCurrent(),
        valveOpen = nv.valveState,
        timestamp = date().time,
        rssi = imp.rssi(),
        firmwareVersion = imp.getsoftwareversion(),
        hardwareVersion = "0.0.1" //this SHOULD be hardcoded, right?
    });
}
function receiveInstructions(instructions){
    server.log("received New Instructions");
    local sleepUntil = 0;
    server.log(instructions.open);
    server.log(instructions.nextCheckIn);
    local change = false;
    //if neither of the below statements 
    //TODO: battery check before opening
    try{
        if(instructions.open == true && nv.valveState == false){
            //sleep to ensure we don't open/close valve too quickly
            imp.sleep(0.5);
            agent.send("valveStateChange" , {valveOpen = true});
            open();
            change = true;
            server.log("opening Valve");
        }
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
    if(change == true){
        //TODO: change this to just take a second reading and send it instead
        agent.send("valveStateChange" , {valveOpen = nv.valveState});
    }
    if(!unitTesting){
        if(nv.valveState == true){
            //do not allow the valve to accept times greater than defaults:
            if(instructions.nextCheckIn > valveOpenMaxSleepTime){
                deepSleepForTime(valveOpenMaxSleepTime * 60.0);
                return 
            }
            else{
                deepSleepForTime(instructions.nextCheckIn * 60.0);
                return 
            }
        }
        else if(nv.valveState == false){
            if(instructions.nextCheckIn > valveCloseMaxSleepTime){
                deepSleepForTime(valveCloseMaxSleepTime * 60.0);
                return 
            }
            else{
                deepSleepForTime(instructions.nextCheckIn * 60.0);
                return 
            }
        }
        //this should NEVER occur, but is here for safety's sake
        deepSleepForTime(valveOpenMaxSleepTime * 60.0);
    }
}

agent.on("receiveInstructions", receiveInstructions);

function onConnectedCallback(state) {
    // If we're connected...
    if (state == SERVER_CONNECTED) {
        sendData();
    } 
    else {
        // Otherwise, do something else
    }
}


function connect(callback, timeout) {
    // Check if we're connected before calling server.connect()
    // to avoid race condition
    if (server.isconnected()) {
        // We're already connected, so execute the callback
        callback(SERVER_CONNECTED);
    } 
    else {
        // Otherwise, proceed as normal
        server.connect(callback, timeout);
    }
}

function main(){
    chargingConfigure();
    blueConfigure();
    redConfigure();
    greenConfigure();
    valvePinInit();
    valveConfigure();
    connect(onConnectedCallback , TIMEOUT_SERVER_S);
}
if(!unitTesting){
    main();
}

