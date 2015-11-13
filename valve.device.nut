const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);
unitTesting <- false;


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
    imp.wakeup(0.5,function() {
        imp.onidle(function() {
            server.sleepfor(inputTime);
        });
    });
}

//Send data to agent
//dummy values currently in use
//these lines intentionally don't have semicolons
function sendData(){
    agent.send("sendData", {
        macId = imp.getmacaddress(),
        wakereason = hardware.wakereason(),
        batteryLevel = 3.3,
        solarLevel = 4.3,
        valveOpen = nv.valveState,
        timestamp = date().time,
        rssi = imp.rssi(),
        firmwareVersion=0.1
    });
}

agent.on("receiveInstructions",function(instructions){
    server.log("received New Instructions");
    local sleepUntil = 0;
    server.log(instructions.open);
    server.log(instructions.nextCheckIn);
    //if neither of the below statements 
    //TODO: battery check before opening
    if(instructions.open == true && nv.valveState == false){
        //sleep to ensure we don't open/close valve too quickly
        imp.sleep(0.5);
        agent.send("valveStateChange" , {valveOpen = true});
        open();
        server.log("opening Valve");
    }
    else if (instructions.open == false && nv.valveState == true){
        imp.sleep(0.5);
        agent.send("valveStateChange" , {valveOpen = false});
        close();
        server.log("closing valve");
    }
    deepSleepForTime(instructions.nextCheckIn * 60.0);
});

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
