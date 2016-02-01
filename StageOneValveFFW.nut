//Stage 1 will result in the unit NOT being blessed
//LEDs will ONLY show up in this order:
//EIMP lights will display regularly if not connected
//Solid blue+green: connected but RSSI too low to pass
//Solid red: waiting for all charging systems to pass first check
//Solid yellow: testing valve on/off and charger stats
//Solid white: battery too low to ship 
//Blinking Green/yellow rapid: ready to be turned off and pass to the next stage of the line
//Blinking white: failed blessing, must be turned off and retested


//"NO LOCK PRODUCTION CODE"

devMac <- imp.getmacaddress();
edynDevs <- ["0c2a690a2e2b","0c2a6908e8c1","0c2a6908a8f9","0c2a6908f8b2","0c2a690890d4","0c2a69090e9d","0c2a690907c5","0c2a6908fbc2","0c2a6908e8b8","0c2a69090f86","0c2a6908c4e1","0c2a69090f86"];
factoryDevs <- ["0c2a690a2e2b","0c2a6908e8c1","0c2a6908a8f9","0c2a6908f8b2","0c2a690890d4","0c2a69090e9d","0c2a690907c5","0c2a6908fbc2","0c2a6908e8b8","0c2a69090f86","0c2a6908c4e1","0c2a69090f86"];
devType <- "None";
debug <- true;

const ssid = "Ellsworth AP"
const pw = "ellsworth1"
//This is required to get the "yellow blinking" behavior once the customer receives the device.
if(imp.getssid() == ""){
    while(1){}
}

const ssid = "Ellsworth AP"
const pw = "ellsworth1"

chargingPollAveraging <- 15.0;

//TODO: populate these values

//first check Readings
firstBatVol <- 0.0;
firstSolarVol <- 0.0;
firstChargeCur <- 0.0;
firstRSSIValue <- 0;

//first check minimums
firstBatMin <- 3.28;//~25-30% SOC on the battery, we'll be increasing this later
firstSolarMin <- 4.5;//calibrated in factory
firstChargeMin <- (-0.03);//calibrated in factory ~= -0.04 when not charging
//Need to figure out a good value for RSSI once we start production:
firstRSSIMin <- (-60);

//first check maximums
firstBatMax <- 3.9;//above this is DANGEROUS!!! (like start a fire dagerous)
firstSolarMax <- 6.0;
firstChargeMax <- 1.0;

//first check passbools
firstBatPass <- false;
firstSolarPass <- false;
firstChargePass <- false;
firstRSSIPass <- false;

//second check minimum battery reading
secondBatMin <- 3.25;

//second check battery reading
secondBatVol <- 0.0;

//DL=debug loop, meant for debugging when no console is available
//should NEVER be called in final production code
function DL(){
    hardware.pin5.configure(DIGITAL_OUT)
    while(1){
        hardware.pinC.write(1)
        imp.sleep(1)
        hardware.pinC.write(0)
        imp.sleep(1)
    }
}

try{
            
        
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
        
}
catch(error){}

function blinkupRoutine(){
    server.factoryblinkup(ssid, pw, hardware.pinC, BLINKUP_FAST);
    imp.wakeup(5.0,blinkupRoutine)
}

function configureDev(){
    for (local x = 0; x < edynDevs.len(); x++){
        if(devMac == edynDevs[x]){
            server.log("edyn dev")
            hardware.pinC.configure(DIGITAL_OUT);
            redConfigure();
            greenConfigure();
            hardware.pinC.write(0)
            greenOn();
            redOn();
            imp.sleep(90);
            greenOff();
            redOff();
            hardware.pinC.write(1)
            devType = "Edyn"
            blinkupRoutine()
            return
        }
    }
    devType = "Prod"
}


configureDev()


if(devType == "Prod"){
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
            for (local x = 0;x<chargingPollAveraging;x++){
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
        
        //checks all charging related systems and wifi strength
        //valve is checked before any of this is run.
        function checkSystems(){
            local readings = {};
            local rssiTemp = 0;
            
            //RSSI test: blue + green
            blueOn()
            greenOn()
            redOff()
            while(!firstRSSIPass){
                imp.sleep(1);
                rssiTemp = imp.rssi();
                if(rssiTemp > firstRSSIMin && !firstRSSIPass){
                    firstRSSIPass = true;
                    firstRSSIValue = rssiTemp;
                }
                else if (!firstRSSIPass){
                    server.log("rssi failed" + firstRSSIMin)
                }
            }
            
            //Valve AND Charger: disconnect and yellow
            server.disconnect();
            redOn();
            blueOff();
            while(!firstSolarPass || !firstChargePass){
                open()
                imp.sleep(1)
                readings=getChargingStatus();
                if(readings.solar > firstSolarMin && readings.solar < firstSolarMax && !firstSolarPass){
                    firstSolarPass = true;
                    firstSolarVol = readings.solar;
                }
                if(readings.amperage > firstChargeMin && readings.amperage < firstChargeMax && !firstChargePass){
                    firstChargePass = true;
                    firstChargeCur = readings.amperage;
                }
                close()
                imp.sleep(1)
            }
            server.connect()
            redOn()
            blueOn()
            greenOn()
            
            while(!firstBatPass){
                imp.sleep(1)
                readings = getChargingStatus();
                if(readings.battery > firstBatMin && readings.battery < firstBatMax && !firstBatPass){
                    firstBatPass = true;
                    firstBatVol = readings.battery;
                    server.log("batteryPassed")
                }
            }

            if(firstRSSIPass && firstChargePass && firstSolarPass && firstBatPass){
                server.log("all passed")
                return
            }
        }
        

        //Using this to allow it to charge after testing other systems
        function chargeBattery(){
            local secondBatteryReading = getChargingStatus().battery;
            if(secondBatteryReading < secondBatMin){
                //impossible to have net positive charge while wifi connected
                server.disconnect();
                while(secondBatteryReading < secondBatMin){
                    imp.sleep(10.0);
                    secondBatteryReading = getChargingStatus().battery;
                }
            }
            secondBatVol = secondBatteryReading;
            server.connect();
            return
        }

        //constructs the results table that is saved upon blessing
        function constructResultTable(bless_success){
            local returnTable = {};
            returnTable.macAddress <- devMac;
            returnTable.timestamp <- date().time;
            returnTable.blessSuccess <- bless_success;
            returnTable.firstBatteryVoltage <- firstBatVol;
            returnTable.firstSolarVoltage <- firstSolarVol;
            returnTable.firstChargeCurrent <- firstChargeCur;
            returnTable.firstRSSIValue <- firstRSSIValue;
            returnTable.secondBatteryVoltage <- secondBatVol;
            return returnTable
        }

        function blessDevice(){
            while(!server.isconnected()){
                blueOn();
                redOff();
                greenOff();
                imp.sleep(10);
                server.connect();
            }
            server.bless(true, function(bless_success) { 

                local testResultsTable = constructResultTable(bless_success);
                server.log("I'm being Blessed -> " + devMac);
                server.log("Blessing " + (bless_success ? "PASSED" : "FAILED"));
                agent.send("testresult", testResultsTable)
                while(bless_success) {
                    if (bless_success) {
                        imp.clearconfiguration();
                    }
                    greenOff();
                    redOff();
                    blueOff();
                    imp.sleep(100);
                }
                while(!bless_success) {
                    blueOn();
                    redOn();
                    greenOn();
                    imp.sleep(0.5);
                    blueOff();
                    greenOff();
                    redOff();
                    imp.sleep(0.5);
                }
            });
        }
        
        function main(){
            

            blueConfigure();
            redConfigure();
            greenConfigure();
            /*Uncomment to test blessing on a2dc2
            if(devMac=="0c2a690a2dc2"){
                blueOff()
                redOff()
                greenOff()
                imp.sleep(5)
                blessDevice()
                return
            }
            */
            valvePinInit();
            valveConfigure();
            chargingConfigure();
            
            if(devType == "Prod"){
                /*
                blueOn();
                redOn();
                greenOn();
                imp.sleep(90);
                blueOff();
                redOn();
                greenOff();
                */
                blueOff();
                redOn();
                greenOn();                
                server.log("checkSystemsBegin")
                checkSystems();
                server.log("Check Systems Complete")
                greenOn()
                blueOff()
                redOff()
                while(1){
                    redOff()
                    imp.sleep(0.3)
                    redOn()
                    imp.sleep(0.3)
                }
                #blessDevice();
            }    
        }
        main();  
    }
    catch(error){}
}
