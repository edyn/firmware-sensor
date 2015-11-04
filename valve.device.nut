const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);



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
function deepSleepUntilTime(inputTime){
    //TODO: add some robust error handling to this function in particular
    imp.wakeup(0.5,function() {
        imp.onidle(function() {
            //TODO: if the below expression evaluates negative or inputTime is not a string that's bad
            local sleepTime=inputTime-date().time;
            server.sleepfor(sleepTime);
        });
    });
}

//Send data to agent
//dummy values currently in use
//these lines intentionally don't have semicolons
function sendData(){
    agent.send("sendData", {
        macId=imp.getmacaddress(),
        wakereason=hardware.wakereason(),
        batteryLevel=3.3,
        solarLevel=4.3,
        valveOpen=false,
        timestamp=date().time,
        rssi=imp.rssi()
    });
}

agent.on("receiveInstructions",function(instructions){
    server.log("received New Instructions");
    local sleepUntil=0;
    server.log(instructions.open);
    server.log(instructions.nextCheckIn);
    if(instructions.nextCheckIn<date().time){
        sleepUntil=date().time+3600;
    } else {
        if(instructions.open==true){
            //sleep to ensure we don't open/close valve too quickly
            imp.sleep(0.5);
            open();
            server.log("opening Valve");
        }
        deepSleepUntilTime(instructions.nextCheckIn*60.0);
    }
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
