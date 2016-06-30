/*
Copyright (C) 2014 Electric Imp, Inc
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR ecA PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* ========================================================================================
- the factory blinkup fixture is a factory imp in an April board
  mounted on an enclosure with an LED on pin9 and a button on pin8. When the
  button is pressed it triggers the LED to flash factory BlinkUp code
- the LED on the device's imp card (not the factory blinkup fixure) will turn solid green indicating pass/bless or
  turn solid red indicating fail/no blessing
- the webhooks will then be notified of the blessing event and take further actions
========================================================================================== */

///////////
//Globals//
///////////



//Stage Booleans


//Pre/Post bool for the 2000 run and the post 2000 run
postTwoK <- false;

//Post Mechanical Assembly Test Booleans
humidityTR <- false;
temperatureTR <- false;
ECTR <-false;

//Post Potting Test Booleans
solarVoltageTR <-false;
chargingTR <- false;

//Test Ranges 
//LL - lower limit
//UL - upper limit

//battery lower limit in volts
batteryLL <- 3.3;

//Wifi connection strength lower limit:
//from Electric Imp's page on imp.rssi():
// -67 and above is 5 bars
wifiLL <- -67.0;

//humidity range:
humidityLL<- 0.1;
humidityUL<- 100.0;

//temperature range:
temperatureLL<- 1.0;
temperatureUL<- 60.0;

//EC range:
ECLL <- 1.28;
ECUL <- 1.45;

//Solar Voltage Range:
solarVoltageLL<- 4.0;
solarVoltageUL <- 10.0;

//power manager things:
powerLL <- 32;


//Test Results
humidityResults <- 0.0;
temperatureResults <- 0.0;
solarVoltageResults <- 0.0;
batteryResults <- 0.0;
ECResults <- 0.0;
rssiResults <- 0.0;
ssidResults <- "";

//settings required by borrowed probe code
const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);
POLL_ITERATION_MAX <- 10;



///////////////////////
/// SSID/PW/MAC INFO //
//////////////////////

const EDYNSSID = "Edyn Front";
const EDYNPASSWORD = "edyn1234";
EDYN_MAC <- ["0c2a6908d244", "0c2a6908d178"];
const FIXTURESSID= "EdynWireless";
const FIXTUREPASSWORD = "EdynWireless";
FIXTURE_MAC <- "0c2a69022b94";
FIXTURE_MAC_TWO <- "0c2a69089f11" //board blinker upper
FIXTURE_MAC_THREE <- "0c2a69022baf"; //Austin Office IMP for Dev
FIXTURE_MAC_FOUR <- "0c2a690ae569";
const THROTTLE_TIME = 10;
const SUCCESS_TIMEOUT = 20;
throttle_protection <- false;
finished <- false;
mac <- imp.getmacaddress();
device_id <- hardware.getdeviceid();
bless_success <- false;
deviceType<- "None";
blessing <- false;


function DL(timer) {
    hardware.pin9.configure(DIGITAL_OUT);
    //DEBUGLIGHTS
    while(1) {
        hardware.pin9.write(0);
        imp.sleep(timer);
        hardware.pin9.write(1);
        imp.sleep(timer);
    }
}




////////
//MAIN//
////////

function main() {

    //////////////////////
    //BEHAVIOR SWITCHING//
    //////////////////////
    
    //device deciding whether the device it is production, fixture or an edyn probe PCB for blinkup
    configureDevice(mac);
    
    /////////////////////////////////////
    //TEST CODE FOR PRODUCTION DEVICES //
    /////////////////////////////////////
    
    if(deviceType=="Prod") {
        //sensor configuration for DUTs
        prodConfigure();
        
        //battery test
        batteryResults=source.voltage();
        
        while(batteryResults<batteryLL) {
            batteryResults=source.voltage();
            //purple light if it needs to be turned off and charged
            blueLed.on();
            redLed.on();
            greenLed.off();
        }
    

        //Amber light on until it passes wifi tests:
        redLed.on();
        greenLed.on();
        blueLed.off();
        
        if(postTwoK) {
            //clear wifi so we can test blinkup. Not in the batch of 2000 though
        }
        
        while(!wifiTest()) {
            imp.sleep(0.5);
        }
        
        if(true) {
            redLed.on();
            greenLed.on();
            blueLed.on();
            imp.sleep(90);
        }
 
        
        server.log("RSSI:"+rssiResults);

        //Stage 2: Post Mechanical Assembly
        blueLed.off();
        greenLed.off();
        redLed.on();
        while(!stageTwoProcess()) {
            imp.sleep(0.2);
        }
        
        //Stage 3: Post Potting
        blueLed.on();
        greenLed.off();
        redLed.off();
        
        while(!stageThreeProcess()) {
            imp.sleep(0.2);
        }
        
        //Stage 4: Blessing
        greenLed.off();
        redLed.off();
        blueLed.off();
        passedAllTests(true);
    }
}

/////////////////////////////////////////////
// EVERYTHING FOR EDYN AND FIXTURE         //
// BLESSING DEVICES IS IN CONFIGUREDEVICE()//
/////////////////////////////////////////////

function factoryBlinkUp() {
    imp.wakeup(10, factoryBlinkUp);
    server.log("Starting EDYN factory blinkup.")
    server.factoryblinkup(EDYNSSID, EDYNPASSWORD, hardware.pin5, 0);
}

function configureDevice(macAddr) {
    //////////
    // EDYN //
    //////////
    
    //Cycle through ALL edyn mac addresses (global array initialized at the top)
    for(local i=0;i<EDYN_MAC.len();i++) {
        //Is one of the mac addresses an in house blessing device?
        if(macAddr==EDYN_MAC[i]) {
            deviceType="Edyn";
            server.log("This is an EDYN imp with mac " + mac + " It will blinkup to SSID " + EDYNSSID);
            hardware.pin2.configure(DIGITAL_OUT);
            hardware.pin5.configure(DIGITAL_OUT);
            hardware.pin2.write(0);
            hardware.pin2.write(1);
            hardware.pin5.write(1);
            factoryBlinkUp();
        }
    }
    

    if(deviceType=="None"&&imp.getssid()!="") {
        deviceType="Prod"
    }
    
    server.log("configuring device: " + macAddr + " as " + deviceType)
    
}

/////////////////////////////
//THE FUNCTION THAT BLESSES//
/////////////////////////////

function passedAllTests(PASSFAIL=false) {
    if(PASSFAIL) {
        server.bless(true, function(bless_success) { 
            if (bless_success) {
                imp.clearconfiguration();
            }
            server.log("I'm being Blessed -> " + mac);
            server.log("Blessing " + (bless_success ? "PASSED" : "FAILED"));
            server.log("DATETIME:")
            agent.send("testresult", {device_id = device_id, mac = mac, success = bless_success, Battery=batteryResults, WifiStrength=rssiResults, SSID=ssidResults, EC = ECResults, Humidity=humidityResults, Temperature=temperatureResults, SolarV=solarVoltageResults, timestamp=date().time});
            
            while(bless_success) {
                greenLed.on();
                redLed.off();
                blueLed.off();
                imp.sleep(100);
            }
            while(!bless_success) {
                blueLed.on();
                redLed.on();
                greenLed.on();
                imp.sleep(0.5);
                blueLed.off();
                redLed.off();
                greenLed.off();
                imp.sleep(0.5);
            }
        //Add the other results:
        });
    }
    else {
        server.log("Unexpected condition");
    }
}

///////////////////////
//Prod Configurations//
///////////////////////

function prodConfigure() {
    
    source.configure();
    local batteryLevelTestResults=false;
    greenLed.configure();
    redLed.configure();
    blueLed.configure();
    //move this to global:
    hardware.pinE.configure(DIGITAL_OUT); 
    //I2C Configurations
    hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
    // sensor configurations
    soil.configure();
    solar.configure();
    // Create PowerManager object
    powerManager <- PowerManager(hardware.i2c89);
    powerManager.setDefs();
    //Create humidityTemperatureSensor object
    humidityTemperatureSensor <- HumidityTemperatureSensor();
}

///////////////////
//Stage Processes//
///////////////////
function stageTwoProcess() {
    //I2CS Sampling
    hardware.pin1.configure(DIGITAL_IN_WAKEUP, function() {})
    humidityTemperatureSensor.sample();
    imp.sleep(0.2);
    
    local buttonState = hardware.pin1.read();
    //humidity
    if(humidityTR!=true) {
        local h = humidityTemperatureSensor.humidity;
        
        if(h>humidityLL&&h<humidityUL) {
            server.log("Humidity Passed");
            humidityResults=h;
            humidityTR=true;
        }
        else {
            server.log("humidity failed " + h );
            hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
            imp.sleep(0.2)
            humidityTemperatureSensor.sample();
        }
    }
    buttonState = hardware.pin1.read()||buttonState;
    //temperature
    if(temperatureTR!=true) {
        local t = humidityTemperatureSensor.temperature;
        
        if(t>temperatureLL&&t<temperatureUL) {
            temperatureTR=true;
            temperatureResults=t;
            server.log("Temperature Passed")
        }
        else {
            server.log("Temperature Failed " + t);
            hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
        }
    }
    buttonState = hardware.pin1.read()||buttonState;
    //EC
    hardware.pinE.write(1);
    ECResults = soil.voltage();
    if(ECTR!=true) {
        server.log("ECRONE:"+ECResults)
        if(ECResults>ECLL && ECResults < ECUL) {
            ECTR=true
        }
    }
    
    buttonState = hardware.pin1.read()||buttonState;
    if(buttonState)
    {
        
        agent.send("testresult", {device_id = device_id, mac = mac, success = bless_success, Battery=batteryResults, WifiStrength=rssiResults, SSID=ssidResults, EC = ECResults, Humidity=humidityResults, Temperature=temperatureResults, SolarV=solarVoltageResults, timestamp=date().time});
           
    }
    if( ECTR&&temperatureTR&&humidityTR) {
        server.log("Tests Passed")
        return true
    }
    else {
        return false
    }
    

}


function stageThreeProcess() {
    
    powerManager.sample();
    if(powerManager.reg_3==null || humidityTemperatureSensor.temperature==32 || humidityTemperatureSensor.humidity == 0) {
        hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
        server.log("Reconfiguring the I2C Bus");
        imp.sleep(2);
    }
    
    //solar voltage
    if(solarVoltageTR!=true) {
        local sv = solar.voltage();
        if(sv>solarVoltageLL&&sv<solarVoltageUL) {
            solarVoltageTR=true
            solarVoltageResults=sv;
            server.log("Solar Voltage Passed")
        }
        else {
            server.log("Solar voltage Failed")
        }
    }
    //charging
    if(chargingTR!=true) {
        server.log("Reg 3:" + powerManager.reg_3);
        
        if(powerManager.reg_3>powerLL) {
            server.log("Charging Passed")
            chargingTR=true
        }
        else {
            server.log("Charging State Failed: " + powerManager.reg_3)
        }
    }
    
    if(chargingTR&&solarVoltageTR) {
        return true
    }
    else {
        return false
    }
}

/////////////
//Wifi Test//
/////////////

function wifiTest() {
    //rssi is the signal strength
    rssiResults = imp.rssi();
    // SSID can be set to something flex specific if we want
    ssidResults = imp.getssid(); 
    return rssiResults>wifiLL
}

///////////////////////////////////////
//BELOW HERE IS COPY+PASTE PROBE CODE//
///////////////////////////////////////

//Probe code includes classes and functions for sensor checking

///
// Classes
///

// Digital LED, active low
try {
    class greenLed {
        //  [Device]  ERROR: the index 'pin' does not exist:  at constructor
        static pin = hardware.pinD;

        function configure() {
            pin.configure(DIGITAL_OUT,1);
            pin.write(1);
        }
        
        function on() {
            pin.write(0);
        }
        
        function off() {
            pin.write(1);
        }
        
        function blink(duration, count = 1) {
            while (count > 0) {
                count -= 1;
                greenLed.on();
                imp.sleep(duration);
                greenLed.off();
                if (count > 0) {
                    // do not sleep on the last blink
                    imp.sleep(duration);
                }
            }
        }
    }
    // Digital LED, active low
    class redLed {
        //  [Device]  ERROR: the index 'pin' does not exist:  at constructor
        static pin = hardware.pin2;

        function configure() {
            pin.configure(PWM_OUT, 1.0/400.0, 0.0);
            pin.write(1.0);
        }
        
        function on() {
            pin.write(0.3);
        }
        
        function off() {
            pin.write(1.0);
        }
        
        function blink(duration, count = 1) {
            while (count > 0) {
                count -= 1;
                redLed.on();
                imp.sleep(duration);
                redLed.off();
                if (count > 0) {
                    // do not sleep on the last blink
                    imp.sleep(duration);
                }
            }
        }
    }

    class blueLed {
      //  [Device]  ERROR: the index 'pin' does not exist:  at constructor
      static pin = hardware.pin5;

      function configure() {
          pin.configure(PWM_OUT, 1.0/400.0, 0.0);
          pin.write(1.0);
      }
      
      function on() {
          pin.write(0.0);
      }
      
      function off() {
          pin.write(1.0);
      }
      function pulse() {
          local blueLedState = 1.0;
          local blueLedChange = 0.05;
          local count = 80;
          while (count >= 0) {
              count -= 1;
              // write value to pin
              pin.write(blueLedState);
          
              // Check if we're out of bounds
              if (blueLedState >= 1.0 || blueLedState <= 0.0) {
                  // flip ledChange if we are
                  blueLedChange *= -1.0;
              }
              // change the value
              blueLedState += blueLedChange;
              imp.sleep(0.05);
          }
      }
      function blink(duration, count = 1) {
          while (count > 0) {
              count -= 1;
              blueLed.on();
              imp.sleep(duration);
              blueLed.off();
              if (count > 0) {
                  // do not sleep on the last blink
                  imp.sleep(duration);
              }
          }
      }
    }
    ////////////////////////
    // Power manager
    ////////////////////////

                    
    class PowerManager {
        _i2c  = null;
        _addr = null;
        static SA_REG_2 = "\x02";
        static SA_REG_3 = "\x03";
        static SA_REG_4 = "\x04";
        static SA_REG_5 = "\x05";
        static SA_REG_0 = "\x00";
        static SA_REG_1 = "\x01";
        
        reg_3 = 0;
        reg_2 = 0;
        reg_0 = 0;
        reg_1 = 0;
        reg_4 = 0;
        reg_5 = 0;
        // static SA_REG_3 = impified_i2c_address.toString();
        
        constructor(i2c) {
            _i2c  = i2c;
            
            // Squirrel automatically sets bit zero to the correct I²C-defined value
            // Please note that many vendors’ device datasheets specify a
            // 7-bit base I²C address. In this case, you will need to
            // bit-shift the address left by 1 (ie. multiply it by 2): 
            // static WRITE_ADDR = "\x09"; // LTC4156 write address as a 7-bit word
            // static WRITE_ADDR = 0x09 << 1; // LTC4156 write address converted to an 8-bit word
            // static WRITE_ADDR = 0x12; // LTC4156 write address converted to an 8-bit word
            // static READ_ADDR = 0x13;
            // Imp I2C API automatically changes the write/read bit
            // Note: Imp I2C address values are integers
            _addr = 0x12;
        }
      
        //Set Defs and Sample are used in conjunction to replace polling loop
        //set defs sets registers to their desired 'default values'

        function setDefs() {    
            local successful=0;
            //REG 1 Info:
            // 0 Wall Input Prioritized +
            // 00 Battery Charger Safety Timer +
            // 00001 500 mA Max WALLILIM 
            // 00000001
            successful+=writeReg(1,"\x01");
            // REG 2 has the V float setting
            // write 1111 (battery charger current at 100% full-scale DEFAULT) + 
            // 11 (vfloat of 3.8V) +
            // 00 (full capacity charge indication threshold of 10% full-scale current DEFAULT) = 
            // 11111100
            successful+=writeReg(2,"\xFC");
            return successful;
        }
        
        // EVT wifi sensor can measure Solar panel voltage (PIN7)
        // and output voltage (PINB)
        // Once PIN7>PINB voltage & charging is enabled electricimp
        // needn’t be sleeping and control charging

        //runs polling loop six times to populate each register
        function sample() {
            // The transaction is initiated by the bus master with a START condition
            // The SMBus command code corresponds to the sub address pointer value
            // and will be written to the sub address pointer register in the LTC4156
            // Note: Imp I2C command values are strings with 
            // the \x escape character to indicate a hex value
            
            //REG 0:Charge current, float voltage, c/x detection
            reg_0=readReg(0);
            //Reg 1:Charger functionality
            reg_1=readReg(1);
            //REG 2:V float
            reg_2=readReg(2);
            //REG 3:Charger status
            reg_3=readReg(3);
            // REG 4:External power
            reg_4=readReg(4);
            // REG 5:Ntc warning
            reg_5=readReg(5);
        }
        //0.1 charging functions enable/disable/suspend/resume
        //check the logic of 0C and FC in reg 2
        //0.2 Changed to make the functions not overwrite vfloat settings

        function suspendCharging() {
            writeReg(1,"\x0F");
        }
        //01 is our default setting of 500ma Max
        function resumeCharging(toWrite=0x00) {
            writeReg(1,"\x01");
        }

        function readReg(subreg,trynum=0,maxtry=5) {
            local returnValue=null;
            switch(subreg) {
                case 0:
                    returnValue = _i2c.read(_addr, SA_REG_0, 1);
                break
                case 1:
                    returnValue = _i2c.read(_addr, SA_REG_1, 1);
                break
                case 2:
                    returnValue = _i2c.read(_addr, SA_REG_2, 1);
                break
                case 3:
                    returnValue = _i2c.read(_addr, SA_REG_3, 1);
                break
                case 4:
                    returnValue = _i2c.read(_addr, SA_REG_4, 1);
                break
                case 5:
                    returnValue = _i2c.read(_addr, SA_REG_5, 1);
                break
            }  
          
            if(returnValue!=null) {
                returnValue=returnValue[0] & 0xff;
            }
            else {
                if(trynum>=maxtry) {
                    returnValue=null;
                }
                else {
                    returnValue=readReg(subreg,trynum+1,maxtry);
                }
            }
            return returnValue;
        }

        function writeReg(subreg,valuex,trynum=0,maxtry=5) {
            local returnValue=-1;
            switch(subreg) {
                case 0:
                    returnValue = _i2c.write(_addr, SA_REG_0+valuex);
                break
                case 1:
                    returnValue = _i2c.write(_addr, SA_REG_1+valuex);
                break
                case 2:
                    returnValue = _i2c.write(_addr, SA_REG_2+valuex);
                break
                case 3:
                    returnValue = _i2c.write(_addr, SA_REG_3+valuex);
                break
                case 4:
                    returnValue = _i2c.write(_addr, SA_REG_4+valuex);
                break
                case 5:
                    returnValue = _i2c.write(_addr, SA_REG_5+valuex);
                break
            }  
            if(returnValue!=0){
                if(trynum<maxtry){
                    returnValue=writeReg(subreg,valuex,trynum+1,maxtry);
                }
            }
            return returnValue;
        }
        
        //0.1
        //Set vfloat based on battery voltage, close is defaulted to 0.03 volts
        //feature 0.2
        //now this does not overwrite the MSB when changing vfloat
        function changevfloat(inputVoltage,close=0.03) {
            //TODO: add MSB input: ,MSBin="" to set MSB
            //local vfloatin=nv.chargertwo.slice(3,3);
            //local chargestate=nv.chargertwo.slice(2,2);
            
            //local oldreg=regToArr("\x02");
            //local vfloatin=oldreg[1];
            //local MSBin=oldreg[0];
            /*In reg 2, vfloat is controlled by the 3rd and 4th LSB:
            xxxx00xx=3.45
            xxxx01xx=3.55
            xxxx10xx=3.60
            xxxx11xx=3.80 (This is our default setting)
            note that this function only works if the two LSB in reg 2 remain xxxxxx00
            */   
            if(inputVoltage<3.55-close) {
               nv.PMRegC[1]=0x00;
               writeToReg("\x02",nv.PMRegC[0],nv.PMRegC[1]);
            }
            else if (inputVoltage<3.60-close) {       
               nv.PMRegC[1]=0x04;
               writeToReg("\x02",nv.PMRegC[0],nv.PMRegC[1]);
            }
            else if(inputVoltage<3.8-close) {       
               nv.PMRegC[1]=0x08;
               writeToReg("\x02",nv.PMRegC[0],nv.PMRegC[1]);
            }
            else {
               nv.PMRegC[1]=0x0C;
               writeToReg("\x02",nv.PMRegC[0],nv.PMRegC[1]);
            }
        } //end changevfloat

    } //end PM class

    ////////////////////////////////////////////////////////////
    // HTU21D ambient humidity sensor
    ////////////////////////////////////////////////////////////
    class HumidityTemperatureSensor {
        static ADDRESS = 0x80; // = 0x28 << 1
        static COMMAND_MODE_BIT = 0x80;
        static STATUS_STALE_BIT = 0x40;
        static SUB_ADDR_TEMP = "\xE3";
        static SUB_ADDR_HUMID = "\xE5";  
        static i2c = hardware.i2c89;
        humidity = 0.0;
        temperature = 0.0;

        constructor() {
            i2c.configure(CLOCK_SPEED_400_KHZ);
        }
        //samples retrieves the humidity and temperature register values
        //converts them and returns them
        function sample() {
            local humidity_raw, temperature_raw, iteration = 0;
            local dataHum = null;
            local dataTem = null;
            // Measurement Request - wakes the sensor and initiates a measurement
            // if (trace == true) server.log("Sampling temperature");
            // if (trace == true) server.log(i2c.write(ADDRESS, SUB_ADDR_TEMP).tostring());
            // if (i2c.write(ADDRESS, SUB_ADDR_TEMP) == null)
            //  return -1;
            // Data Fetch - poll until the 'stale data' status bit is 0
            do {
                //sleep only after the first iteration    
                if(iteration>0){
                    imp.sleep(0.1);
                }
                if(dataTem==null){
                    dataTem=i2c.read(ADDRESS, SUB_ADDR_TEMP, 2);
                }
                if(dataHum==null){
                    dataHum= i2c.read(ADDRESS, SUB_ADDR_HUMID, 2);
                }
                // if (trace == true) server.log("Read attempt");
                // timeout
                iteration += 1;
                if (iteration > POLL_ITERATION_MAX)
                    break;
            } while (dataHum==null||dataTem==null);
            //log("TemPoll= " + temPoll.tostring() + "   HumPoll= " + humPoll.tostring()+"  Iterations=" + iteration.tostring());
            // THE TWO STATUS BITS, THE LAST BITS OF THE LEAST SIGNIFICANT BYTE,
            // MUST BE SET TO '0' BEFORE CALCULATING PHYSICAL VALUES
            // This happens automatically, though, through the i2c.read function
            // is_data_stale = data[0] & STATUS_STALE_BIT;
            // Mask for setting two least significant bits of least significant byte to zero
            // 0b11111100 = 0xfc
            //server.log(data[0]);
            //server.log(data[0] << 8);
            //server.log(data[1]);
            //server.log(data[1] & 0xfc);

            if(dataTem!=null) {
                temperature_raw = (dataTem[0] << 8) + (dataTem[1] & 0xfc);
                temperature = temperature_raw * 175.72 / 65536.0 - 46.85;
            }
            // Measurement Request - wakes the sensor and initiates a measurement
            // if (trace == true) server.log("Sampling humidity");
            // if (trace == true) server.log(i2c.write(ADDRESS, SUB_ADDR_HUMID).tostring());
            // Data Fetch - poll until the 'stale data' status bit is 0

            if(dataHum!=null) {
                humidity_raw = (dataHum[0] << 8) + (dataHum[1] & 0xfc);
                humidity = humidity_raw * 125.0 / 65536.0 - 6.0;
            }
        }
    }


    // VREF is VSYS – voltage=2.8V 
    // PIN A- ADC_S – soil moisture sensor (up to Vsys) 
    // Soil probe voltage sensor
    class soil {
        pin = hardware.pinA;

        function configure() {
            pin.configure(ANALOG_IN);
        }
        
        function voltage() {
            return (pin.read()/65536.0) * hardware.voltage();
        }
    }

    // LTC4156 system voltage (divided by/2, charger voltage or battery voltage)
    class source {
        pin = hardware.pinB;
        
        function configure() {
            pin.configure(ANALOG_IN);
        }
        
        function voltage() {
            return 2.0 * (pin.read()/65536.0) * hardware.voltage();
        }  
    }


    // PIN 7 – ADC_AUX – measurement solar cell voltage (divided by/3, limited to zener 
    // voltage 6V) 
    // Solar voltage sensor
    class solar {
        static pin = hardware.pin7;

        function configure() {
            pin.configure(ANALOG_IN);
        }
        
        function voltage() {
            // measures one third voltage divider, multiply by 3 to get the actual
            return 3.0 * (pin.read()/65536.0) * hardware.voltage();
        }
    }


    // Power management
    class power {
        function enter_deep_sleep_running(reason) {
            //Old version before Electric Imp's sleeping fix
            //imp.deepsleepfor(INTERVAL_SENSOR_SAMPLE_S);
            //Implementing Electric Imp's sleeping fix
            if (debug == true) server.log("Deep sleep (running) call because: "+reason);
            imp.wakeup(0.5,function() {
                imp.onidle(function() {
                    if (debug == true) server.log("Starting deep sleep (running).");
                    // if (trace == true) server.log("Note that subsequent 'sensing' wakes won't log here.");
                    // if (trace == true) server.log("The next wake to log will be the 'data transmission' wake.");
                    //blueLed.on();
                    server.sleepfor(INTERVAL_SENSOR_SAMPLE_S);
                });
            });
        }
        
        function enter_deep_sleep_ship_store(reason) {
            // nv.running_state = false;
            //Old version before Electric Imp's sleeping fix
            //imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
            //Implementing Electric Imp's sleeping fix
            //blueLed.pulse();
            if (debug == true) server.log("Deep sleep (storage) call because: "+reason)
            imp.wakeup(0.5,function() {
                imp.onidle(function() {
                    if (debug == true) server.log("Starting deep sleep (ship and store).");
                    blueLed.on();
                    server.sleepfor(INTERVAL_SLEEP_SHIP_STORE_S);
                });
            });
        }

        function enter_deep_sleep_failed(reason) {
            // nv.running_state = false;
            //Old version before Electric Imp's sleeping fix
            //imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
            //Implementing Electric Imp's sleeping fix
            redLed.blink(0.1,6);
            if (debug == true) server.log("Deep sleep (failed) call because: "+reason)
            imp.wakeup(0.5,function() {
                imp.onidle(function() {
                    if (debug == true) server.log("Starting deep sleep (failed).");
                    blueLed.on();
                    server.sleepfor(INTERVAL_SLEEP_FAILED_S);
                });
            });
        }
    }

    ///
    // End of classes
    ///




    function blinkAll(duration, count = 1) {
        while (count > 0) {
            count -= 1;
            blueLed.on();
            redLed.on();
            greenLed.on();
            imp.sleep(duration);
            blueLed.off();
            redLed.off();
            greenLed.off();
            if (count > 0) {
                // do not sleep on the last blink
                imp.sleep(duration);
            }
        }
    }

    //0.0.1.1
    //should return a string that can be written to a register
    //needs some testing
    function toHexStr(firstByte="0",secondByte="0") {
        return "\\x"+firstByte+secondByte;
    }

    class soil {
        pin = hardware.pinA;

        function configure() {
            pin.configure(ANALOG_IN);
        }
        
        function voltage() {
            return (pin.read()/65536.0) * hardware.voltage();
        }
    }

    //0.0.1.1
    //added unit test here
    function unitTest() {
    }

}

catch(error) {

}

switch (mac) {

    case FIXTURE_MAC:
        //it's getting here
        server.log("This is the factory imp with mac " + mac + " and factory blinkup fixture device ID " + device_id + ". It will blinkup to SSID " + FIXTURESSID);
        hardware.pin9.configure(DIGITAL_OUT);

        hardware.pin9.write(0);
        hardware.pin8.configure(DIGITAL_IN_PULLUP, function() {
            local buttonState = hardware.pin1.read();
            if (buttonState == 0) {
                // Start the actual blinkup (which includes asking the server for a factory token)
                server.log("Starting factory blinkup.")
                hardware.pin9.write(1);
                imp.wakeup(0.2, function() {
                    hardware.pin9.write(0);
                    imp.sleep(0.1);
                    server.factoryblinkup(FIXTURESSID, FIXTUREPASSWORD, hardware.pin9, BLINKUP_ACTIVEHIGH | BLINKUP_FAST);
                   // agent.send("testresult", {device_id = device_id, mac = mac, msg = "Starting factory blinkup."})
                })
            }
        })
        break;
    case FIXTURE_MAC_TWO:
        //it's getting here
        server.log("This is the factory imp with mac " + mac + " and factory blinkup fixture device ID " + device_id + ". It will blinkup to SSID " + FIXTURESSID);
        hardware.pin5.configure(DIGITAL_OUT);

        hardware.pin5.write(0);
        hardware.pin1.configure(DIGITAL_IN_PULLUP, function() {
            local buttonState = hardware.pin1.read();
            if (buttonState == 0) {
                // Start the actual blinkup (which includes asking the server for a factory token)
                server.log("Starting factory blinkup.")
                hardware.pin5.write(0);
                imp.wakeup(0.2, function() {
                    hardware.pin5.write(1);
                    imp.sleep(0.1);
                    server.factoryblinkup(FIXTURESSID, FIXTUREPASSWORD, hardware.pin5, BLINKUP_FAST);
                   // agent.send("testresult", {device_id = device_id, mac = mac, msg = "Starting factory blinkup."})
                })
            }
        })
        break;
    case FIXTURE_MAC_THREE:
        //it's getting here
        server.log("This is the factory imp with mac " + mac + " and factory blinkup fixture device ID " + device_id + ". It will blinkup to SSID " + FIXTURESSID);
        hardware.pin9.configure(DIGITAL_OUT);
        server.log("HEREERERERER")
        hardware.pin9.write(0);
        hardware.pin8.configure(DIGITAL_IN_PULLUP, function() {
            local buttonState = hardware.pin1.read();
            if (buttonState == 0) {
                // Start the actual blinkup (which includes asking the server for a factory token)
                server.log("Starting factory blinkup.")
                hardware.pin9.write(1);
                imp.wakeup(0.2, function() {
                    hardware.pin9.write(0);
                    imp.sleep(0.1);
                    server.factoryblinkup(FIXTURESSID, FIXTUREPASSWORD, hardware.pin9, BLINKUP_ACTIVEHIGH | BLINKUP_FAST);
                   // agent.send("testresult", {device_id = device_id, mac = mac, msg = "Starting factory blinkup."})
                })
            }
        })
        break;
        
        
    //EDYN FIXTURE MAC
    case FIXTURE_MAC_FOUR:
        //it's getting here
        server.log("This is the factory imp with mac " + mac + " and factory blinkup fixture device ID " + device_id + ". It will blinkup to SSID " + FIXTURESSID);
        hardware.pin5.configure(DIGITAL_OUT);

        hardware.pin5.write(0);
        hardware.pin1.configure(DIGITAL_IN_PULLUP, function() {
            local buttonState = hardware.pin1.read();
            if (buttonState == 0) {
                // Start the actual blinkup (which includes asking the server for a factory token)
                server.log("Starting factory blinkup.")
                hardware.pin5.write(0);
                imp.wakeup(0.2, function() {
                    hardware.pin5.write(1);
                    imp.sleep(0.1);
                    server.factoryblinkup(EDYNSSID, EDYNPASSWORD, hardware.pin5, BLINKUP_FAST);
                   // agent.send("testresult", {device_id = device_id, mac = mac, msg = "Starting factory blinkup."})
                })
            }
        })
        break;
    default:
        main();
    
}



