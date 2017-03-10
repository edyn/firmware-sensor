////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
// 0.0.2.2
// Imp Device code collects sensor data and sends it to
// the Imp Cloud. In between sensor samplings, the device
// will remain in deep sleep. To conserve power, the device
// does not send data to the server each time it samples.
// Samples are stored in a buffer and sent with
// varying frequency based on battery life and data delta.
// If there is a wifi communication error, the device will
// resume after a timeout.
//
// TODO:ch
// - need ability to reset (magnetic reset, or power switch)
// - merge similar consecutive data points
// - return error data (i2c sensor error, etc) to host
// - interleave sensor sampling to reduce awake time
// - give up when the device doesn't see wifi
////////////////////////////////////////////////////////////

const TIMEOUT_SERVER_S = 10; // timeout for wifi connect and send
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);

const INTERVAL_SENSOR_SAMPLE_S = 600; // sample sensors this often
const INTERVAL_SLEEP_FAILED_S = 600; // sample sensors this often
// const INTERVAL_SLEEP_MAX_S = 2419198; // maximum sleep allowed by Imp is ~28 days
const INTERVAL_SLEEP_SHIP_STORE_S = 2419198;
const POLL_ITERATION_MAX = 5; // maximum number of iterations for sensor polling loop
// New setting now that we're recording register values
const TZ_OFFSET = -25200; // 7 hours for PDT
const blinkupTime = 90;
//Loggly Timeout Variable:
const logglyConnectTimeout = 20;

const HIGHEST_FREQUENCY = 300; //60 seconds * 5
const HIGH_FREQUENCY = 600;   //60 seconds * 10
const MEDIUM_FREQUENCY= 1800;  //60 seconds * 30
const LOW_FREQUENCY = 3600;    //60 seconds * 60
const LOWER_FREQUENCY = 6000; //60 seconds * 100
const LOWEST_FREQUENCY = 7200;//60 seconds * 240

const HIGHEST_BATTERY = 3.4;         //Volts
const HIGH_BATTERY = 3.35
const MEDIUM_BATTERY = 3.3;      //Volts
const LOW_BATTERY = 3.24;         //Volts
const LOWER_BATTERY = 3.195;        //Volts

const CONNECTION_TIME_ON_ERROR_WAKEUP = 30;

const NV_SIZE_LIMIT = 2900; //bytes, value taken from valve code
const STORED_ERRORS_MAX = 3; //stored errors

const LOG_DETAILED_MOISTURE_DATA = false;
debug <- false; // How much logging do we want?
trace <- false; // How much logging do we want?
coding <- false; // Do you need live data right now?
demo <- false; // Should we send data really fast?
ship_and_store <- false; // Directly go to ship and store?
firstPress<-false;
// offline logging
offline <- [];
pressit<- 0;
attemptNumber <- 0;
//0.0.1.1
//if runtest is true, the unit test defined below main will run
runTest<-false;
//0.0.1.2
maxBatteryTemp<- 60.0;
minBatteryTemp<- 0.0;
//0.0.1.3
//Intelligence and control flow global variables
wakeR<-null;
nextWakeCall<-null;
shallow<-false;
whenWake<- 0;
intlast<- 0;
branchSelect <- 0;
intertime<-0;
//0.0.2.2
//Capacitance Sensing
highread<- 0;
timeDiffOne<- 0;
timeDiffTwo<- 0;
lastReading<- 0;
eScalar <- (1.0-0.36787);
escalarTwo <- 0.36787;
lastLastReading<- 0;
readingDebug <- false
samplerHzA<- 900000;
samplerHzB<- 2000
buffer1 <- blob(20000);
buffer2 <- blob(20000);
sendFullRead <- false;

theCurrentTimestamp <- time()

agent.on("fullRes",function(data){
    sendFullRead = true
    server.log("FULL RES FUNCTION")
    server.log("FULL RES BABY")
    agent.send("fullRes", {
    bend=buffer1,
    tail=buffer2,
    macid=hardware.getdeviceid()
    timestamp=theCurrentTimestamp.tostring()
    })
})

agent.on("syncOSVersion", function(data){
    agent.send("syncOSVersionFromDevice", imp.getsoftwareversion());
})


//Needs to be moved to the proper location
function configCapSense()
{
    hardware.pinE.configure(DIGITAL_OUT);
}


function capSense(ModeSelect=true){
    //initializations

    local capacitance = 0;
    hardware.pinE.configure(DIGITAL_OUT);
    local maxVSoil=0;
    local  minVSoil=66000;
    local lastlastreading=0;
    local kneeIndex=0;
    local kneeThresh=-1.00;
    local vmaxIndex=0;
    local eNegOne=0.632;
    local thresheNeg=-1.00;
    local indexeNeg=0
    //configurations
    hardware.sampler.configure(hardware.pinA, 900000, [buffer1], samplesReady);
    hardware.sampler.start();
    //take a reading
    hardware.pinE.write(1);
    imp.sleep(0.1)
    hardware.sampler.stop()
    hardware.sampler.configure(hardware.pinA, 10000, [buffer2], samplesReady);
    hardware.sampler.start();
    if(ModeSelect==true){
        if(readingDebug==true){
        server.log("RegularCapsense")
        }
        imp.sleep(1)
    }
    else
    {
        if(readingDebug==true){
        server.log("ColdBootCapsense")
        }
        imp.sleep(1)
    }
    //1 second for the minimum read
    //The sampler stops at 200 ms - thought it was 2 seconds!!!! AGH!
    hardware.sampler.stop();
    local lastreading=hardware.pinA.read()
    imp.sleep(0.01)
    //server.log(hardware.pinA.read())
    hardware.pinE.write(0);
    //Can't use max() function because the reading is in two pieces and creating an array of 'actual' readings would take more memory
    //So we do it this way which only takes a couple of bytes more:
    //finding the capacitance
    local kneeIndex=0;

    for(local z=19998;z>=0;z-=2)
    {
        local currentReading=0
        currentReading=(buffer1[z+1]*256)+buffer1[z]
        if(currentReading>maxVSoil)
        {
            maxVSoil=currentReading
            vmaxIndex=z/2
            thresheNeg=maxVSoil*eNegOne
            kneeThresh=0.10*maxVSoil
        }
    }

    for(local z=0;z<20000;z+=2)
    {
        local currentReading=0
        currentReading=(buffer1[z+1]*256)+buffer1[z]
        if(currentReading>thresheNeg&&indexeNeg==0)
        {
            indexeNeg=z/2
        }
        if(currentReading>kneeThresh&&kneeIndex==0)
        {
            kneeIndex=z/2
        }
    }
    server.log("Index:")
    server.log(indexeNeg-kneeIndex)
    //SHOULD return data like a normal function, but right now it just stores data in global variables
    lastReading=lastreading
    lastLastReading=lastReading
    lastlastreading=lastLastReading
    //timeDiffOne=threshBendIndex
    timeDiffTwo=indexeNeg-kneeIndex
    highread=maxVSoil
    //debugs
    if(LOG_DETAILED_MOISTURE_DATA){
      server.log("Last Sample:")
      server.log(lastreading)
      server.log("MaxVSoil:")
      server.log(maxVSoil)
      server.log("Knee Index:")
      server.log(kneeIndex)
      server.log("indexeNeg:")
      server.log(indexeNeg)
      server.log("timeDiffTwo:")
      server.log(timeDiffTwo)
      server.log("MaxIndex:")
      server.log(vmaxIndex)
      server.log("LastLastReading:")
      server.log(lastlastreading)
    }
}
//Should move to something like this eventually to do analysis, but
// right now it's just needed for capsense to work:
function samplesReady(a,b){}

///
// Classes
///

// Digital LED, active low
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
    pin.write(0.5);
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
    // static WRITE_ADDR = 0x09 << 1; // LTC4156 write address converted to
    // an 8-bit word
    // static WRITE_ADDR = 0x12; // LTC4156 write address converted to
    // an 8-bit word
    // static READ_ADDR = 0x13;
    // Imp I2C API automatically changes the write/read bit
    // Note: Imp I2C address values are integers
    _addr = 0x12;
  }

//Set Defs and Sample are used in conjunction to replace polling loop
//set defs sets registers to their desired 'default values'
    function setDefs()
    {
        local successful=0;
    //REG 1 Info:
    // 0 Wall Input Prioritized +
    // 00 Battery Charger Safety Timer +
    // 00001 500 mA Max WALLILIM
    // 00000001
        successful+=writeReg(1,"\x00");
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

  function suspendCharging()
  {
    writeReg(1,"\x0F");
  }
  //01 is our default setting of 500ma Max
  function resumeCharging(toWrite=0x00)
  {
    writeReg(1,"\x00");
  }

  function readReg(subreg,trynum=0,maxtry=5)
  {
    local returnValue=null;
    switch(subreg)
    {
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

      if(returnValue!=null){
        returnValue=returnValue[0] & 0xff;
      }
      else
      {
        if(trynum>=maxtry)
        {
            returnValue=null;
        }
        else
        {
            returnValue=readReg(subreg,trynum+1,maxtry);
        }
      }
      return returnValue;
  }
  function writeReg(subreg,valuex,trynum=0,maxtry=5)
  {
    local returnValue=-1;
    switch(subreg)
    {
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
  function changevfloat(inputVoltage,close=0.03)
  {
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
    if(inputVoltage<3.55-close)
    {
       nv.PMRegC[1]=0x00;
       writeToReg("\x02",nv.PMRegC[0],nv.PMRegC[1]);
    }
    else if (inputVoltage<3.60-close)
    {
       nv.PMRegC[1]=0x04;
       writeToReg("\x02",nv.PMRegC[0],nv.PMRegC[1]);
    }
    else if(inputVoltage<3.8-close)
    {
       nv.PMRegC[1]=0x08;
       writeToReg("\x02",nv.PMRegC[0],nv.PMRegC[1]);
    }
    else
    {
       nv.PMRegC[1]=0x0C;
       writeToReg("\x02",nv.PMRegC[0],nv.PMRegC[1]);
    }
  }//end changevfloat
}//end PM class

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
    // Mask for setting two least significant bits of least significant
    // byte to zero
    // 0b11111100 = 0xfc
    //server.log(data[0]);
    //server.log(data[0] << 8);
    //server.log(data[1]);
    //server.log(data[1] & 0xfc);

    if(dataTem!=null)
    {
    temperature_raw = (dataTem[0] << 8) + (dataTem[1] & 0xfc);
    temperature = temperature_raw * 175.72 / 65536.0 - 46.85;
    }
    // Measurement Request - wakes the sensor and initiates a measurement
    // if (trace == true) server.log("Sampling humidity");
    // if (trace == true) server.log(i2c.write(ADDRESS, SUB_ADDR_HUMID).tostring());
    // Data Fetch - poll until the 'stale data' status bit is 0

    if(dataHum!=null)
    {
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



// PIN 7 – ADC_AUX – measurement solar cell voltage (divided by/3,
// limited to zener voltage 6V)
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
    //TODO: change inputTime to be the input of the function
    local inputTime = INTERVAL_SENSOR_SAMPLE_S;
    server.log("Deep sleep (running) call because: "+reason);
    imp.wakeup(0.5,function() {
      imp.onidle(function() {
        if (debug == true) server.log("Starting deep sleep (running).");
        //if (trace == true) {
        //  server.log("Note that subsequent 'sensing' wakes won't log here.");
        //}
        //if (trace == true) {
        //  server.log("The next wake to log will be the 'data transmission' wake.");
        //}
        //blueLed.on();
        server.sleepfor(inputTime);
      });
    });
  }

  function enter_deep_sleep_ship_store(reason) {
    // nv.running_state = false;
    //Old version before Electric Imp's sleeping fix
    //imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
    //Implementing Electric Imp's sleeping fix
    //blueLed.pulse();
    //TODO: change inputTime to be the input of the function
    local inputTime = INTERVAL_SLEEP_SHIP_STORE_S;
    server.log("Deep sleep (storage) call because: " + reason);
    imp.wakeup(0.5,function() {
      imp.onidle(function() {
        if (debug == true) server.log("Starting deep sleep (ship and store).");
        blueLed.on();
        server.sleepfor(inputTime);
      });
    });
  }

  function enter_deep_sleep_failed(reason) {
    // nv.running_state = false;
    //Old version before Electric Imp's sleeping fix
    //imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
    //Implementing Electric Imp's sleeping fix
    redLed.blink(0.1,6);
    //TODO: change inputTime to be the input of the function
    local inputTime = INTERVAL_SLEEP_FAILED_S;
    if (debug == true) server.error("\tDeep sleep (failed) call because: "+reason)
    imp.wakeup(0.5,function() {
      imp.onidle(function() {
        if (debug == true) server.log("Starting deep sleep (failed).");
        blueLed.on();
        if(imp.rssi()){
            server.sleepfor(inputTime);
        }
        else{
            server.sleepfor(inputTime);
        }

      });
    });
  }
}

///
// End of classes
///

///
// Functions
///

//Loggly Functions
function forcedLogglyConnect(state, logTable, logLevel){
    try{
        // If we're connected...
        if (state == SERVER_CONNECTED) {
            agent.send(logLevel, logTable);
            return
        }
        else {
            power.enter_deep_sleep_failed("Forced Loggly Connect Failed");
            return
        }
    } catch (error) {
        server.error("\t" + error)
        logglyError({
            "error" : error,
            "function" : "forcedLogglyConnect",
            "message" : "failure when trying to force device to connect and send to loggly"
        });
        power.enter_deep_sleep_failed("Error in forced loggly connect");
    }
}

function logglyGeneral(logTable = {}, forceConnect = false, level = "INFO"){
  logglyLevel <- "Log"
  if (level == "ERROR") {
    logglyLevel = "Error"
  } else if (level == "WARN") {
    logglyLevel = "Warn"
  } else {
    logglyLevel = "Log"
  }
  try{
    if(server.isconnected()){
        //Uncomment this in the future when unit testing is implemented on the sensor similar to the valve
        //logTable.UnitTesting <- unitTesting;
        agent.send("loggly" + logglyLevel, logTable)
    } else if(forceConnect){
        //connect and send loggly stuff
        //really no reason we'd ever force a connect for a regular log...
        server.connect(function (connectStatus){
            forcedLogglyConnect(server.isconnected(), logTable, "loggly" + logglyLevel);
        }, logglyConnectTimeout);
    }
  } catch (error) {
    server.error("\tLoggly " + level +  " Error: " + error);
  }
}

function logglyLog(logTable = {}, forceConnect = false){
  logglyGeneral(logTable, forceConnect, "INFO");
}

function logglyWarn(logTable = {}, forceConnect = false){
  logglyGeneral(logTable, forceConnect, "WARN");
}

//TODO: make server logging optional part of logglyerror
function logglyError(logTable = {}, forceConnect = false){
    logglyGeneral(logTable, forceConnect, "ERROR");
}


function log(s) {
  local now = time() + TZ_OFFSET;
  s = format("%02d:%02d:%02d - %s",date(now).hour, date(now).min, date(now).sec, s);
  if (server.isconnected()) {
    foreach(a in offline) server.log(a);
    offline.clear();
    server.log("ONLINE: "+s);
  } else {
    offline.append("OFFLINE: "+s);
  }
}

function logDeviceOnline()
{
    local reasonString = "Unknown"
    switch(hardware.wakereason())
    {
        case WAKEREASON_POWER_ON:
            reasonString = "The power was turned on"
            break

        case WAKEREASON_SW_RESET:
            reasonString = "A software reset took place"
            break

        case WAKEREASON_TIMER:
            reasonString = "An event timer fired"
            break

        case WAKEREASON_PIN1:
            reasonString = "Pulse detected on Wakeup Pin"
            break

        case WAKEREASON_NEW_SQUIRREL:
            reasonString = "New Squirrel code downloaded"
            break

        case WAKEREASON_SQUIRREL_ERROR:
            reasonString = "Squirrel runtime error"

        case WAKEREASON_NEW_FIRMWARE:
            reasonString = "impOS update"
            break

        case WAKEREASON_SNOOZE:
            reasonString = "A snooze-and-retry event"
            break

        case WAKEREASON_HW_RESET:
            // imp003 only
            reasonString = "Hardware reset"
    }

    server.log("Reason for waking/reboot: " + reasonString)
}

function onConnectedTimeout(state) {
  //If we're connected...
  if (state == SERVER_CONNECTED) {
    // ...do something
    if (debug == true) server.log("After allowing a chance to blinkup, succesfully connected to server.");
    main();
  }
  else {
    // Otherwise, do something else
    // power.enter_deep_sleep_ship_store("Conservatively going into ship
    // and store mode after failing to connect to server.");
    if (debug == true) {
      server.error("\tGave a chance to blink up, then tried to connect to server but failed.");
    }
    power.enter_deep_sleep_failed("Sleeping after failing to connect to server after a button press.");
  }
}

function connect(callback, timeout) {
  //using a comma in the line below to avoid 'find and replace' error
  // Check if we're connected before calling server,connect()
  // to avoid race condition

  if (server.isconnected()) {
    if (debug == true) server.log("Server connected");
    // We're already connected, so execute the callback
    nv.pastConnect=true;
    logFreeNVMemory();
    if(nv.storedErrors.len()){
      sendStoredErrors();
    }
    callback(SERVER_CONNECTED);
  }
  else {
    if (debug == true) server.log("Need to connect first");
    // Otherwise, proceed as normal
    server.connect(
      function(connectionStatus){
        try{
          logFreeNVMemory();
          //always send errors if possible
          if(nv.storedErrors.len()){
            sendStoredErrors();
          }
          callback(connectionStatus)
        } catch(error) {
          server.error("\terror in callback from function 'connect'")
          logglyError({
              "message" : "Error in connect's callback function",
              "Error" : error
          });
          //reason doesn't matter, and we're using deep sleep running just because it's 10 minutes
          power.enter_deep_sleep_running("error in callback from connect");
        }
      },
    timeout);
  }
}



// return true if the collected data should be sent to the server
function isServerRefreshNeeded(lastSentData, currentData){
  //note: we used to send data more fruently if it was rapidly changing by comparin currentData to lastDataSent
  //if we've never sent data, send data.
  if (debug) server.log("debug mode");
  if(lastSentData == null) {
    return true
  }
  //if we're connected, might as well send
  if(server.isconnected()){
    return true
  }
  local sendInterval = 0;
  // send updates more often when the battery is full
    if (currentData.b > HIGHEST_BATTERY){
      sendInterval = HIGH_FREQUENCY; // battery full
    } else if (currentData.b > HIGH_BATTERY) {
      sendInterval = HIGH_FREQUENCY; // battery very high
    } else if (currentData.b > MEDIUM_BATTERY){
        sendInterval = HIGH_FREQUENCY;   // battery high
    } else if (currentData.b > MEDIUM_BATTERY){
      sendInterval = HIGH_FREQUENCY;  // battery medium
    } else if (currentData.b > LOW_BATTERY) {
      sendInterval= HIGH_FREQUENCY;  // battery getting low
    } else if (currentData.b > LOWER_BATTERY) {
      sendInterval = LOWER_FREQUENCY; // battery low
      server.log("Low Vout from LTC4156.");
    } else {
      return false //battery critical!
    }
    return ((currentData.ts - lastSentData.ts) > sendInterval);
}


// Callback for server status changes.
function send_data(status) {
  // update last sent data (even on failure, so the next send attempt is not immediate)
  local power_manager_data=[];
  local nvDataSize = nv.data.len();
  nv.data_sent = nv.data.top();

  if (server.isconnected()) {
    // ok: send data
    // server.log(imp.scanwifinetworks());
    //
    power_manager_data.append(powerManager.reg_0);
    power_manager_data.append(powerManager.reg_1);
    power_manager_data.append(powerManager.reg_2);
    power_manager_data.append(powerManager.reg_3);
    power_manager_data.append(powerManager.reg_4);
    power_manager_data.append(powerManager.reg_5);
    if (debug == true) server.log("Connected to server.");
    //if RSSI is 0, check it again
    if(nvDataSize > 0){
      if(nv.data[nvDataSize - 1].r == 0){
        nv.data[nvDataSize - 1].r = imp.rssi();
      }
    }
    agent.send("data", {
      device = hardware.getdeviceid(),
      data = nv.data,
      power_data=power_manager_data
    }); // TODO: send error codes

    local success = server.flush(TIMEOUT_SERVER_S);

    if (success) {
      // update last sent data (even on failure, so the next send attempt is not immediate)
      nv.data_sent = nv.data.top();

      // clear non-volatile storage
      nv.data.clear();
    }

    else {
      server.error("\tError: Server connected but failed to send data");
    }
  }
  //urgent todo: this doesn't seem to belong here AT ALL:
  else {
    //guaranteed that this won't work:
    if (debug == true) server.error("\tTried to connect to server to send data but failed.");
    power.enter_deep_sleep_failed("Sleeping after failing to connect to server for sending data.");
  }
  if(sendFullRead)
  {
      server.log("FULL RES BABY")
      agent.send("fullRes", {
      bend=buffer1,
      tail=buffer2,
      macaddr=hardware.getdeviceid()

  }); // TODO: send error codes
    local success = server.flush(TIMEOUT_SERVER_S);
    if (success) {
          // update last sent data (even on failure, so the next send attempt is not immediate)
          server.log("Should have sent")

    }
    else
    {
        server.error("\tdid not send")
    }
  }

  else{
        server.log(sendFullRead)
        server.log("NOT FULL RES")
  }
  if (ship_and_store == true) {
    power.enter_deep_sleep_ship_store("Hardcoded ship and store mode active.");
  }
  else {
    // Sleep until next sensor sampling
    power.enter_deep_sleep_running("Finished sending JSON data.");
  }
}

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
function toHexStr(firstByte="0",secondByte="0")
{
  return "\\x"+firstByte+secondByte;
}



//0.0.1.1
//added unit test here
function unitTest()
{
}

const TAKE_READING_AND_BLINKUP = 1;
const TAKE_READING_NO_BLINKUP = 2;



//0.0.1.2
function determineBranchFromWakeReason()
{
    wakeR=hardware.wakereason();
    local branching = "unknown";
    switch(wakeR)
    {
        //Wake reasons with a blinkup phase

        case WAKEREASON_POWER_ON:
            branching = TAKE_READING_AND_BLINKUP;
            break

        case WAKEREASON_PIN1:
            branching = TAKE_READING_AND_BLINKUP;
            break


        //Wake reasons that don't have a blinkup phase

        case WAKEREASON_SW_RESET:
            branching = TAKE_READING_NO_BLINKUP;
            //This DOES try to force connection
            logglyError({
              "error" : "Waking From Software Reset (OS level Error, could be memory related)"
            });
            break

        case WAKEREASON_NEW_SQUIRREL:
            branching = TAKE_READING_NO_BLINKUP;
            break

        case WAKEREASON_NEW_FIRMWARE:
            branching = TAKE_READING_NO_BLINKUP;
            break

        case WAKEREASON_SQUIRREL_ERROR:
            branching = TAKE_READING_AND_BLINKUP;
            //This DOES try to force connection
            logglyError({
              "error" : "Waking From Squirrel Runtime Error"
            }, true);
            break

        case WAKEREASON_TIMER:
            branching = TAKE_READING_NO_BLINKUP;
            break

        case WAKEREASON_BLINKUP:
            branching = TAKE_READING_NO_BLINKUP;
            break

        //unlikely/impossible cases (arbitrarily no blinkup)

        case WAKEREASON_SNOOZE:
            branching = TAKE_READING_NO_BLINKUP;
            break

        case WAKEREASON_HW_RESET:
            branching = TAKE_READING_NO_BLINKUP;
            break

        case null:
            branching = TAKE_READING_NO_BLINKUP;
            server.error("\tBad Wakereason");
            logglyError({
              "error" : "wake reason is null"
            });
            break
    }//endswitch
    return branching
}//endcontrolflow


//new interrupt handler, to prevent interruptPin() from running twice
function interrupthandle()
{
    if(branchSelect != 3)
    {
        interruptPin();
    }
}

//interruptPin is tied to the pin wakeup condition of the device
//the user can check the on/off status of the device by pressing the button once
//the user then has 5 seconds (for which the LED will be green) to press
//the button again
//pressing the button a second time enables blinkup

function interruptPin() {

    try{
      branchSelect = 4;
      hardware.pin1.configure(DIGITAL_IN_WAKEUP, interrupthandle);
        //explanation of the below if statement:
        //Intertiem is recorded at the end of the interrupt
        //(and initialized as 0)
        //When you press the button, the code begins with an instance
        //of interruptpin queued up
        //BUT it also recognizes your press as another call to the interrupt
        //so the if statement below ensures the interrupt only runs once
        //per press
        //Let me know if this explanation is unclear because it's very
        //important that if I die tomorrow somebody understands this
      if((date().time-intertime)>1){
          //we might be able to remove this sleep all together
          imp.sleep(1)
        blinkupFor(blinkupTime)
          if (debug == true){
            server.log("Button pressed");
          }
      }

        intertime=date().time;
        //if the imp has not connected before, use shallow sleep.
    if(nv.pastConnect==false){
          //hasn't connected before, wait 60 before sleep
          hardware.pin1.configure(DIGITAL_IN_WAKEUP, interrupthandle);
          wakeCallHandle(60.0,function()
          {
            power.enter_deep_sleep_failed("Has Never Connected");
          });
        }
        else {
            //connected before: no disadvantage to deep sleep
            power.enter_deep_sleep_running("HasConnectedBefore");
        }
    }//end of try
    catch(error){
        server.error("\t" + error);
        blinkAll(2,2);
        //error occurred in interrupt, control=4 and run main
        power.enter_deep_sleep_running("Interrupt Error");
    }//end catch
}

function blinkupFor(timer=90){
    greenLed.configure();
    blueLed.configure();
    redLed.configure();
    // Enable blinkup for 30s
    imp.enableblinkup(true);
    blueLed.on()
    redLed.on()
    greenLed.on()
    //change the sleep to 90
    imp.sleep(timer);
    blueLed.off()
    redLed.off()
    greenLed.off()
    imp.enableblinkup(false);
}

//table size estimator, accurate 'to within 100 bytes' (not very accurate)
//because of this 100 byte resolution, we should avoid writing to the nv when it's size is 3800-3900 bytes
function estimateSize(v) {
    if(v == null){
      return 0;
    }
    // Every table as a 4 byte size, then the entries, then a null, count
    // size and trailing null to start with
    local t = 4+1;
    foreach(a,b in v) {
        if (typeof v == "table") {
            // BSON entries have type, name (cstring), then data
            // Here we count the type and name with terminating nill
            t += 1+a.len()+1;
        } else {
            // It's an array, there's a type byte per entry
            t += 1;
        }
        switch(typeof b) {
            case "table":
            case "array":
            t += estimateSize(b);
            break;
            case "integer":
            case "float":
            t += 4;
            break;
            case "bool":
            t+=1;
            break;
            case "string":
            t += 4+b.len()+1;
            break;
        }
    }
    return t;
}

//future todo: you could determine how many and which readings to throw away before removing any
function trimStoredNVReadingsEvenly(inputDataSize){
    //recalculate each time and check for readings:
    try{
        while((NV_SIZE_LIMIT - estimateSize(nv)) < inputDataSize && nv.data.len()){
            local indexToRemove = 0;
            local smallestTimeGap = 1893484800; //60 year time gap, so large it guarantees ANY real time gap is smaller
            //collect gaps if there's more than one reading
            if(nv.data.len() > 1){
                for(local i = 1; i < nv.data.len(); i++){
                    local currentIndexGap = nv.data[i].ts - nv.data[i - 1].ts;
                    if(currentIndexGap < smallestTimeGap){
                        smallestTimeGap = currentIndexGap;
                        indexToRemove = i;
                    }
                }
            }
            //never remove the first reading (we can if we want to)
            if(indexToRemove == 0){
                return false
            }
            nv.data.remove(indexToRemove);
        }
        return true;
    } catch (error){
        //cannot risk saving this to nv! just return false I guess
        server.log("error in trimStoredNVReadingsEvenly: " + error);
        return false
    }
}

function saveReadingToNV(reading){
    try{
        local readingSize = estimateSize(reading);
        local nvSize = estimateSize(nv);
        local saveReadingTable = {}
        saveReadingTable = clone(reading);
        //trim the nv table if there isn't enough room:
        if(trimStoredNVReadingsEvenly(readingSize)){
            nv.data.append(saveReadingTable);
        } else {
            //can't log this in any way dealing the the NV table safely
            server.log("failed to make room for reading");
        }
    } catch (error) {
        server.log(error)
        logglyError({
            "error" : error,
            "function" : "saveReadingToNV",
            "message" : "Error saving a reading to NV on failed connection"
        });
        power.enter_deep_sleep_running("error in saving nv reading to table")
    }
}

function collectReadingData(){
    local tempReading ={
        ts = theCurrentTimestamp,
        t = humidityTemperatureSensor.temperature,
        h = humidityTemperatureSensor.humidity,
        l = solar.voltage(),
        m = lastLastReading*(3.0/65536.0),
        b = source.voltage(),
        c = timeDiffTwo*(1.0/samplerHzA),
        r = imp.rssi(),
        w = hardware.wakereason()
    }
    return tempReading
}

//only useful if you're connected
function logFreeNVMemory(){
    try{
        local nvSize = estimateSize(nv);
        local freeNV = NV_SIZE_LIMIT - nvSize;
        local numberReadings = nv.data.len();
        local readingsSize = estimateSize(nv.data);
        local averageReadingSize = 0.0;
        if(numberReadings){
            averageReadingSize = readingsSize / numberReadings;
        }
        server.log("REMAINING NV MEMORY: " + freeNV);
        logglyLog({
            "freeNVMemory" : freeNV,
            "readingsSize" : readingsSize,
            "numberReadings" : numberReadings,
            "averageReadingSize" : averageReadingSize,
            "non-readings size" : nvSize - readingsSize
        });
    } catch(error){
        server.log("error in logFreeNVMemory: " + error)
        return
    }
}

function pushError(errorTable){
    local numberStoredErrors = nv.storedErrors.len();
    //less than maximum number stored are in the nv table:
    //trim the nv readings if there isn't enough room since errors are more important:
    if(trimStoredNVReadingsEvenly(estimateSize(errorTable))){
        if(numberStoredErrors < STORED_ERRORS_MAX){
            nv.storedErrors.append(errorTable);
        } else {
            //record if the circular buffer is full
            if(numberStoredErrors < STORED_ERRORS_MAX + 1){
                //this technically makes the length of STORED_ERRORS_MAX above STORED_ERRORS_MAX but it's important.
                nv.storedErrors.append({
                    "error" : "More than " + STORED_ERRORS_MAX + " errors since sendStoredErrors last succeeded"
                });
            }
            //iterate the circular buffer
            nv.storedErrors[nv.storedErrorsCircularIndex] = errorTable;
            nv.storedErrorsCircularIndex += 1;
            if(nv.storedErrorsCircularIndex >= STORED_ERRORS_MAX){
                nv.storedErrorsCircularIndex = 0;
            }
        }
    }
}

function checkForStoredErrors(){
  return nv.storedErrors.len();
}

function sendStoredErrors(){
    try{
        local numberErrors = nv.storedErrors.len();
        //if len returns 0, numberReadings is interpreted as false
        if(numberErrors){
            if(server.isconnected()){
                //the reason for 2 for loops is so that we can do the "safe" version of recording first
                for (local errIterator = 0; errIterator < numberErrors; errIterator++){
                    server.log(nv.storedErrors[errIterator]);
                }
                //and the "dangerous" version second, 
                //as logglyError could be throwing errors, but server.log probably isn't
                for (local errIterator = 0; errIterator < numberErrors; errIterator++){
                    logglyError(nv.storedErrors[errIterator]);
                }
                if(server.flush(20)){
                    nv.storedErrors = [];
                }
            }
        }
    } catch (error) {
        //we don't want this to stop operations for the whole device, so this catch needs to be super safe
        //it's better to not send errors at all than create new ones
        server.log("ERROR SENDING STORED ERRORS: " + error)
    }
}

//functions that are useful for testing NV safety:
//todo before releasing functional tests: remove these comments from production code and make them available in a test document"

//local testNVSafetyLoop(){
//    local z = 0
//    local y = 0
//    while(1){
//        testNVSafety()
//        if(z < 100) {
//            z++
//            if(!(z%10)){
//              logFreeNVMemory();
//            }
//        } else {
//            server.log("DONE WITH RUN NUMBER " + y)
//            y++
//            nv.data = []
//            sendStoredErrors();
//        }
//    }
//}

//function testNVSafety(){
//  local roll = 1.0 * math.rand() / RAND_MAX;
//  if(roll < 0.25){
//        local newReading = collectReadingData();
//        saveReadingToNV(newReading);
//  } else if(roll < 0.5) {
//        local newReading = {"ts" : time(), "ABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCD" : "ABCD"}
//        saveReadingToNV(newReading);
//  } else if (roll < 0.75) {
//        pushError({"message" : "ABCD", "a" : "b", "c" : "d", "e" : "f" , "g" : "h"})
//  } else {
//        pushError({"ABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCD" : "ABCD"});
//  }
//  logFreeNVMemory();
//}

function regularOperation(){

      if (debug == true) server.log("Device booted.");
      if (debug == true) server.log("Device's unique id: " + hardware.getdeviceid());
      server.log("Device firmware version: " + imp.getsoftwareversion());
      server.log("Memory free: " + imp.getmemoryfree());
      // Configure i2c bus
      // This method configures the I²C clock speed and enables the port.

      ///
      // Event handlers
      ///
      // Register the disconnect handler
      server.onunexpecteddisconnect(disconnectHandler);

      //set the pin interrupt
      hardware.pin1.configure(DIGITAL_IN_WAKEUP, interrupthandle);

      ///
      // End of event handlers
      ///

      ////////////////////
      // Configurations //
      ////////////////////

      hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

      //LED configurations
      greenLed.configure();
      redLed.configure();
      blueLed.configure();

      // sensor configurations
      soil.configure();
      solar.configure();
      source.configure();

      // Create PowerManager object
      powerManager <- PowerManager(hardware.i2c89);
      powerManager.setDefs();

      //Create humidityTemperatureSensor object
      humidityTemperatureSensor <- HumidityTemperatureSensor();

      //Configure Capacitive sensing:
      configCapSense();

      server.log("Memory free after configurations: " + imp.getmemoryfree());

      ///
      // End of Configurations
      ///

      if (ship_and_store == true) {
        power.enter_deep_sleep_ship_store("Hardcoded ship and store mode active.");
      }

      // we have entered the running state
      nv.running_state = true;

      ///////////////////////
      // Sample, Save, Send//
      ///////////////////////

      //Sampling

      //capSense returns nothing, see the function itself

      capSense(true);

      lastLastReading=lastLastReading*(0.666)
      powerManager.sample();
      try{
      imp.sleep(0.1);
      if(powerManager.reg_3==null){
          local counterI2C=1;
          while(powerManager.reg_3==null && counterI2C<6){
              //arbitrary, possibly unnecessary sleeps that might make it more
              //stable
              //"check redundancies twice"

              server.log("POWER MANAGER FAIL # " + counterI2C);
              server.log(powerManager.reg_3)
              imp.sleep(0.01);
              hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
              imp.sleep(0.1);
              powerManager.sample();
              imp.sleep(0.1);
              counterI2C+=1;
          }
          //will show up only when it's probably true:
          if(powerManager.reg_3==null){
            server.error("\tPossible damage to the LTC or I2C busses.");
          }
      }else{
          imp.sleep(0.1)
      };
      }
      catch(error){
          server.error("\tLTC SAMPLING ERROR");
      }

      //server.log("PM PASS");
      humidityTemperatureSensor.sample();
      try{
        if(humidityTemperatureSensor.humidity==0 || humidityTemperatureSensor.temperature==32){
            local counterI2C=1;
            while((humidityTemperatureSensor.humidity==0 || humidityTemperatureSensor.temperature==32) && counterI2C<6){
                //arbitrary, possibly unnecessary sleeps that might make it more stable
                //"check redundancies twice"
                server.log("HUMIDITY TEMPERATURE FAIL # " + counterI2C)

                server.log(humidityTemperatureSensor.humidity)
                server.log(humidityTemperatureSensor.temperature)
                imp.sleep(0.01);
                hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
                imp.sleep(0.1);
                humidityTemperatureSensor.sample();
                imp.sleep(0.1);
                counterI2C+=1;
            }
            //will show up only when it's probably true:
            if(humidityTemperatureSensor.humidity==0 || humidityTemperatureSensor.temperature==32){
              server.error("\tPossible damage to the Humidity/Temperature Sensor or I2C busses.");
            }
        }
      } catch(error){
        server.error("\tHum/Temp Error");
      }

      //server.log("Humidity/Temperature Pass")
      server.log("Memory free after sampling: " + imp.getmemoryfree());

      //End Sampling
      //Begin Saving

        // store sensor data in non-volatile storage
        //suspend charging
        powerManager.suspendCharging();
        local batvol = source.voltage();
        //uncomment this sleep to get the light reading value change:
        imp.sleep(0.1);
        local newReading = collectReadingData();
        saveReadingToNV(newReading);

        //resume charging
        powerManager.resumeCharging();

      // End Saving
      //Begin Sending

        //feature 0.2 important
        //Send sensor data
        if (isServerRefreshNeeded(nv.data_sent, nv.data.top())) {
          if (debug == true) server.log("Server refresh needed");
          if(server.isconnected()){
              send_data();
          } else {
              //TODO: THIS IS NOT SAFE (no try/catch):
              connect(send_data, TIMEOUT_SERVER_S);
          }
                // if (debug == true) server.log("Sending location information
                // without prompting.");
            // connect(send_loc, TIMEOUT_SERVER_S);
        }

        // ///
        // all the important time-sensitive decisions based on current state
        // go here
        // ///

        // // checking source voltage not necessary in the first pass
        // // since power will be cut to the imp below Vout of 3.1 V
        // if (source.voltage() < 3.19) {
        //   power.enter_deep_sleep_running("Low system voltage.");
        // }
        // if temperature is too hot
        // if temperatuer is too cold

        else {
          server.log("Not time to send");
          if (ship_and_store == true) {
            power.enter_deep_sleep_ship_store("Hardcoded ship and store mode active.");
          }
          else {
            // not time to send. sleep until next sensor sampling.
            power.enter_deep_sleep_running("Not time yet");
          }
        }
    }
    //end regularOperation


// create non-volatile storage if it doesn't exist
if (!("nv" in getroottable() && "data" in nv)) {
    nv<-{
        data = [],
        data_sent = null,
        running_state = true, PMRegB=[0x00,0x00],
        PMRegC=[0x00,0x00],
        pastConnect=false,
        storedErrors = [],
        storedErrorsCircularIndex = 0
    };
}

function main() {
    hardware.pin1.configure(DIGITAL_IN_WAKEUP, function(){});

    //used for functional tests:
    server.log("main");

    branchSelect = determineBranchFromWakeReason();
    hardware.pin1.configure(DIGITAL_IN_WAKEUP, interrupthandle);
    if(branchSelect == 1){
        if(server.isconnected()){
            //might be able to remove this sleep all together
            imp.sleep(1)
            regularOperation()
        }

    //blinkupfor should happen before regular operation, but we can fix
    //that later
        blinkupFor(blinkupTime)
    }

    else if(branchSelect == 2){
        regularOperation()
    }
    //3 =Pin Wakeup, do some configurations
    else if(branchSelect == 3){
      hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
      source.configure();
      local counterI2C=0;
      powerManager <- PowerManager(hardware.i2c89);
      greenLed.configure();
      blueLed.configure();
      redLed.configure();
      //blueLed.blink(1,3);
      hardware.pin1.configure(DIGITAL_IN_WAKEUP, interrupthandle);
      interruptPin();

    }//end control 3
    //control 5 is blinkup
    else if (branchSelect == 5){
        //TODO: review how blinkup is handled, it's pretty weird
        if(server.isconnected()){
            logglyLog({"message: " : "New Blinkup"});
            blueLed.configure()
            //blueLed.blink(2,2)
            server.log("Is connected")
            regularOperation()
        } else {
            blueLed.configure()
            //blueLed.blink(1,4)
            server.log("not connected")
            blinkupFor(blinkupTime)
        }
    }
}//end main

// Define a function to handle disconnections

function disconnectHandler(reason) {
  if (reason != SERVER_CONNECTED){
    //guaranteed not to run (how could it ever?):
    if (debug == true) server.error("\tUnexpectedly lost wifi connection.");
    power.enter_deep_sleep_failed("Unexpectedly lost wifi connection.");
  }
}


function wakeCallHandle(time=null,func=null) {
    if(time==null&&func==null){
        if(nextWakeCall!=null){
            imp.cancelwakeup(nextWakeCall);
        }
    }else{
        if(nextWakeCall!=null){
            imp.cancelwakeup(nextWakeCall);
        }
        nextWakeCall=imp.wakeup(time,func);//end naxt wake call
    }
}

///
// End of functions
///
function WatchDog(){
    power.enter_deep_sleep_failed("watchdog")
}

function mainWithSafety(){
  imp.wakeup(1.0,
    function(){
        try{
            main();
        } catch (error){
            logglyError({
                "message" : "error in main on forced connect!", 
                "error" : error,
                "timestamp" : time
            });
                //reason doesn't matter, and we're using deep sleep running just because it's 10 minutes
                power.enter_deep_sleep_running("error in main");
            }
        }
    );
}

WDTimer<-imp.wakeup(300,WatchDog);//end next wake call

try{
    local numberOfErrors = checkForStoredErrors();
    if(!numberOfErrors){
        main();
    } else {
        if(server.isconnected()){
            //adding a little safety:
            try{
                sendStoredErrors();
                mainWithSafety();
            } catch (error){
                server.log("error in sendStoredErrors: " + error);
            }
        } else {
            server.connect(function(connectionStatus){
                //adding a little safety:
                try{
                    sendStoredErrors();
                } catch (error){
                    server.log("error in sendStoredErrors: " + error);
                } 
                mainWithSafety();
            }, CONNECTION_TIME_ON_ERROR_WAKEUP); 
        }
    }
} catch (error) {
    logglyError({
        "message" : "error in main!", 
        "error" : error,
        "timestamp" : time()
    });
    //reason doesn't matter, and we're using deep sleep running just because it's 10 minutes
    power.enter_deep_sleep_running("error in main");
}
