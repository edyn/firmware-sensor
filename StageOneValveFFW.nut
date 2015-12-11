//Stage 1 is ONLY to test the valve functionality.
//Stage 1 will NOT result in blessing

devMac <- imp.getmacaddress();
edynDevs <- ["0c2a690ae569"];
factoryDevs <- ["0c2a690ae569"];
devType <- "None"

const ssid="Edyn Front"
const pw="edyn1234"
function DL(){
    hardware.pin5.configure(DIGITAL_OUT)
    while(1){
        hardware.pin5.write(1)
        imp.sleep(1)
        hardware.pin5.write(0)
        imp.sleep(1)
        
    }
}

function blinkupRoutine(){
    server.factoryblinkup(ssid, pw, hardware.pin5, BLINKUP_FAST);
    imp.wakeup(5.0,blinkupRoutine)
}
function configureDev(){
    for (local x=0; x<factoryDevs.len(); x++){
        if(devMac==edynDevs[x]){
            hardware.pin5.configure(DIGITAL_OUT)
            devType = "Edyn"
            blinkupRoutine()
            return
        }
    }
    devType="Prod"
}


configureDev()



try{
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
    blueConfigure()
    redConfigure()
    greenConfigure()
    valvePinInit()
    valveConfigure()
    if(devType == "Prod"){
        imp.enableblinkup(true);
        blueOn();
        greenOn();
        redOn();
        imp.sleep(90);
        blueOff();
        redOff();
        greenOff();
        while(1){
            open();
            greenOn();
            redOff();
            imp.sleep(5);
            greenOff();
            redOn();
            close();
            imp.sleep(5);
        }
        
    }  
}
catch(error){}
