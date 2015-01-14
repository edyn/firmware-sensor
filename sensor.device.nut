////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
//
// Imp Device code collects sensor data and sends it to
// the Imp Cloud. In between sensor samplings, the device
// will remain in deep sleep. To conserve power, the device
// does not send data to the server each time it samples.
// Samples are stored in a buffer and sent with
// varying frequency based on battery life and data delta.
// If there is a wifi communication error, the device will
// resume after a timeout. 
//
// TODO:
// - need ability to reset (magnetic reset, or power switch)
// - merge similar consecutive data points
// - return error data (i2c sensor error, etc) to host
// - interleave sensor sampling to reduce awake time
// - give up when the device doesn't see wifi
////////////////////////////////////////////////////////////

const INTERVAL_SENSOR_SAMPLE_S = 60; // sample sensors this often
const INTERVAL_SLEEP_FAILED_S = 3600; // sample sensors this often
// const INTERVAL_SLEEP_MAX_S = 2419198; // maximum sleep allowed by Imp is ~28 days
const INTERVAL_SLEEP_SHIP_STORE_S = 2419198;
const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
const POLL_ITERATION_MAX = 100; // maximum number of iterations for sensor polling loop
// const NV_ENTRIES_MAX = 40; // maximum NV entry space is about 55, based on testing
// New setting now that we're recording register values
const NV_ENTRIES_MAX = 19; // maximum NV entry space is about 55, based on testing
const TZ_OFFSET = -25200; // 7 hours for PDT
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

//0.1
//if runtest is true, the unit test defined below main will run
runTest<-false;


///
// Classes
///

// Digital LED, active low
class greenLed {
  //  [Device]  ERROR: the index 'pin' does not exist:  at constructor
  static pin = hardware.pinD;

  function configure() {
    pin.configure(DIGITAL_OUT);
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
    // static WRITE_ADDR = 0x09 << 1; // LTC4156 write address converted to an 8-bit word
    // static WRITE_ADDR = 0x12; // LTC4156 write address converted to an 8-bit word
    // static READ_ADDR = 0x13;
    // Imp I2C API automatically changes the write/read bit
    // Note: Imp I2C address values are integers
    _addr = 0x12;
  }

  function changeBatteryMax() {
    // REG 2 has the V float setting
    // write 1111 (battery charger current at 100% full-scale DEFAULT) + 
    // 11 (vfloat of 3.8V) +
    // 00 (full capacity charge indication threshold of 10% full-scale current DEFAULT) = 
    // 11111100

    local result = _i2c.write(_addr, SA_REG_2 + "\xFC");
    // if (trace == true) server.log(result.tostring());
  }

  
  
  //the polling loop used to populate registers
  //polls up to 100 times, returns the result once it's attained.
  //To be implemented: 
  //1)callback function  
  //2)double checking safety/functionality of null vs 0x0
  function pollingLoop(subreg, stringtocat=""){
    local iteration =0;
    local word = 0x0;
    _i2c.write(_addr, subreg+stringtocat) 
    do {
    word = _i2c.read(_addr, subreg, 1);
    iteration += 1;
    if (iteration > POLL_ITERATION_MAX) {
      break;
    }
    } while (word == null);
    return word[0] & 0xff;
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
    reg_0=pollingLoop(SA_REG_0);
    //REG 1 Info:
    // 0 Wall Input Prioritized +
    // 00 Battery Charger Safety Timer +
    // 00001 500 mA Max WALLILIM 
    // 00000001
    reg_1=pollingLoop(SA_REG_1,"\x01");
    // REG 2 has the V float setting
    // write 1111 (battery charger current at 100% full-scale DEFAULT) + 
    // 11 (vfloat of 3.8V) +
    // 00 (full capacity charge indication threshold of 10% full-scale current DEFAULT) = 
    // 11111100
    reg_2=pollingLoop(SA_REG_2,"\xFC");
    //REG 3:Charger status
    reg_3=pollingLoop(SA_REG_3);
    // REG 4:external power
    reg_4=pollingLoop(SA_REG_4);
    // REG 5:ntc warning
    reg_5=pollingLoop(SA_REG_5);
    // server.log(output);
    // _i2c.readerror();
    // Wait for the sensor to finish the reading
    // while ((_i2c.read(_addr, SA_REG_3 + "", 1)[0] & 0x80) == 0x80) {
    //  server.log(_i2c.read(_addr, SA_REG_3 + "", 1));
    // }
    // timeout
  }
  //0.1 charging functions enable/disable/suspend/resume
  //check the logic of 0C and FC in reg 2
  function enableCharging() {
    //local chargerstate= regToArr(registerNumber)[1].tostring();
    //nv.chargertwo="\x0"+nv.chargertwo.slice(3,3);
    //_i2c.write(_addr, SA_REG_2 + nv.chargertwo);
    _i2c.write(_addr, SA_REG_2 + "\x0C");
  }
  function disableCharging() {
    //local chargerstate= regToArr(registerNumber)[1].tostring();
    //nv.chargertwo="\xF"+nv.chargertwo.slice(3,3);
    //_i2c.write(_addr, SA_REG_2 + nv.chargertwo);
    _i2c.write(_addr, SA_REG_2 + "\xFC"+chargerstate);
  }
  function suspendCharging(toWrite="\x00"){
    _i2c.write(_addr, SA_REG_1 +toWrite);
    //pollingLoop(SA_REG_1,"\x00");
  }
  //01 is our default setting of 500ma Max
  function resumeCharging(toWrite="\x01"){
    _i2c.write(_addr, SA_REG_1 + toWrite);
    //pollingLoop(SA_REG_1,"\x01");
  }
    
  //0.1
  //Set vfloat based on battery voltage, close is defaulted to 0.03 volts
  
  function changevfloat(inputVoltage,close=0.03){
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
    if(inputVoltage<3.55-close){
       _i2c.write(_addr, SA_REG_2 + "\xF0");
    }
    else if (inputVoltage<3.60-close){
       _i2c.write(_addr, SA_REG_2 + "\xF4"); 
    }
    else if(inputVoltage<3.8-close){
        _i2c.write(_addr, SA_REG_2 + "\xF8"); 
    }
    else{
        _i2c.write(_addr, SA_REG_2 + "\xFC"); 
    }
    

  }
  
  //0.1
  //returns the value of a register as a string
  //Example call: regToStr("\x02")
  //example return: FC
  function regToStr(registerNumber){
    local word = _i2c.read(_addr, registerNumber, 1);
    return format("%X", word[0] & 0xff)
  }
  //0.1
  //returns two single character strings in an array
  //Example call: regToStr("\x02")
  //example return: [F,C] <-both strings NOT characters 
  function regToArr(registerNumber){
    local word = _i2c.read(_addr, registerNumber, 1);
    local temp = format("%X", word[0] & 0xff);
    return [temp.slice(0,1),temp.slice(1,2)]
  }
  
}

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
    local dataHum = [0x0,0x0];
    local dataTem = [0x0,0x0];
    //temporary arrays to store dataHum and dataTem
    //to avoid fatal error caused by i2c read making data=null and failing loop condition
    local tempTem=[];
    local tempHum=[];
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
      if(dataTem[0]==0&&dataTem[1]==0){
        tempTem=i2c.read(ADDRESS, SUB_ADDR_TEMP, 2);
        if(tempTem!=null){
          dataTem=tempTem;
        }
      }
      if(dataHum[0]==0&&dataHum[1]==0){
        tempHum = i2c.read(ADDRESS, SUB_ADDR_HUMID, 2);
        if(tempHum!=null){
          dataHum=tempHum;
        }
      }
      // if (trace == true) server.log("Read attempt");
      // timeout
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX)
        break;
    } while ((dataHum[0]==0&&dataHum[1]==0) || (dataTem[0]==0&&dataTem[1]==0));
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
    temperature_raw = (dataTem[0] << 8) + (dataTem[1] & 0xfc);
    temperature = temperature_raw * 175.72 / 65536.0 - 46.85;
    // Measurement Request - wakes the sensor and initiates a measurement
    // if (trace == true) server.log("Sampling humidity");
    // if (trace == true) server.log(i2c.write(ADDRESS, SUB_ADDR_HUMID).tostring());
    // Data Fetch - poll until the 'stale data' status bit is 0
    humidity_raw = (dataHum[0] << 8) + (dataHum[1] & 0xfc);
    humidity = humidity_raw * 125.0 / 65536.0 - 6.0;
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
        server.sleepfor(INTERVAL_SENSOR_SAMPLE_S);
      });
    });
  }
  
  function enter_deep_sleep_ship_store(reason) {
    // nv.running_state = false;
    //Old version before Electric Imp's sleeping fix
    //imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
    //Implementing Electric Imp's sleeping fix
    blueLed.pulse();
    if (debug == true) server.log("Deep sleep (storage) call because: "+reason)
    imp.wakeup(0.5,function() {
      imp.onidle(function() {
        if (debug == true) server.log("Starting deep sleep (ship and store).");
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
        server.sleepfor(INTERVAL_SLEEP_FAILED_S);
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
            break
        
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
    // power.enter_deep_sleep_ship_store("Conservatively going into ship and store mode after failing to connect to server.");
    if (debug == true) server.log("Gave a chance to blink up, then tried to connect to server but failed.");
    power.enter_deep_sleep_failed("Sleeping after failing to connect to server after a button press.");
  }
}

function connect(callback, timeout) {
  // Check if we're connected before calling server.connect()
  // to avoid race condition
  
  if (server.isconnected()) {
    if (debug == true) server.log("Server connected");
    // We're already connected, so execute the callback
    callback(SERVER_CONNECTED);
  } 
  else {
    if (debug == true) server.log("Need to connect first");
    // Otherwise, proceed as normal
    server.connect(callback, timeout);
  }
}

//interruptPin is tied to the pin wakeup condition of the device
//the user can check the on/off status of the device by pressing the button once
//the user then has 5 seconds (for which the LED will be green) to press the button again
//pressing the button a second time enables blinkup

function interruptPin() {
  logDeviceOnline();  
  local secondPress=false;
  //first press is needed to prohibit multiple instances of interruptPin from overlapping
  if(firstPress==false){
    firstPress=true;
    local iterator=250;
    //turn the LED green, poll for 5 seconds
    greenLed.on();
    do{
      if(hardware.pin1.read()==1){
        //exit early on button press
        secondPress=true;
        iterator=0;
      }
      iterator-=1;
      imp.sleep(0.02);
    }while(iterator>0)
    greenLed.off();
    if(secondPress==true){
      imp.enableblinkup(true);
      // blueLed.pulse();
      // greenLed.blink(0.1,6);
      // redLed.blink(0.1,6);
      blinkAll(0.1,6);
      // Enable blinkup for 30s
      imp.sleep(30);
      // led.blink(0.1, 10);
      // blueLed.pulse();
      // greenLed.blink(0.1,6);
      // redLed.blink(0.1,6);
      blinkAll(0.1,6);      
      imp.enableblinkup(false);
      // imp.setwificonfiguration("doesntexist", "lalala");  
      firstPress=false;
      connect(onConnectedTimeout, TIMEOUT_SERVER_S);
      // imp.sleep(21);
      // server.connect(send_data, TIMEOUT_SERVER_S);
      firstPress = false;
    }
  }
  
  if (debug == true){
    server.log("Button pressed");
  }  
  firstPress=false;
}

// return true iff the collected data should be sent to the server
function is_server_refresh_needed(data_last_sent, data_current) {
  // first boot, always send
  if (data_last_sent == null)     return true;

  local send_interval_s = 0;
  
  local higher_frequency = 60*5;
  local high_frequency = 60*20;
  local medium_frequency = 60*45;
  local low_frequency = 60*60;
  local lower_frequency = 60*120;
  local lowest_frequency = 60*480;

  if (debug == true) server.log("Debug mode.");

  if (demo == true) {
    server.log("Demo mode.");
    higher_frequency = 60*0;
    high_frequency = 60*1;
    medium_frequency = 60*2;
    low_frequency = 60*5;
    lower_frequency = 60*10;
    lowest_frequency = 60*30;
  }

  // Live coding settings
  else if (demo == false && coding == true) {
    server.log("Coding mode");
    higher_frequency = 60*5;
    high_frequency = 60*5;
    medium_frequency = 60*5;
    low_frequency = 60*5;
    lower_frequency = 60*5;
    lowest_frequency = 60*60;
  }

  
  // Production settings
  else if (demo == false && coding == false) {
    higher_frequency = 60*5;
    high_frequency = 60*10;
    medium_frequency = 60*30;
    low_frequency = 60*60;
    lower_frequency = 60*120;
    lowest_frequency = 60*240;
  }

  // send updates more often when the battery is full
  if (data_current.b > 3.4) {
    send_interval_s = high_frequency; // battery very high
  }
  else if (data_current.b > 3.35) send_interval_s = high_frequency;   // battery high
  else if (data_current.b > 3.3) send_interval_s = high_frequency;  // battery medium
  else if (data_current.b > 3.21) send_interval_s = high_frequency;  // battery getting low
  else if (data_current.b > 3.18) {
    send_interval_s = lower_frequency; // battery low
    server.log("Low Vout from LTC4156.");
  }
  else if (data_current.b > 0.0) return false;             // battery critical
  // else {
  //   // emergency shutoff workaround to prevent the Imp 'red light bricked' state
  //   power.enter_deep_sleep_ship_store("Emergency battery levels.");
  // }

  // // send updates more often when data has changed frequently and battery life is good
  // if (data_current.b > 3.25
  //   && (math.fabs(data_last_sent.t - data_current.t) > 5.0
  //     || math.fabs(data_last_sent.h - data_current.h) > 5.0
  //     || math.fabs(data_last_sent.l - data_current.l) > 50.0
  //     || math.fabs(data_last_sent.m - data_current.m) > 0.2
  //     || math.fabs(data_last_sent.b - data_current.b) > 0.2)) {
  //   if (debug == true) server.log("Data is changing quickly, so send updates more often.");
  //   send_interval_s /= 4;
  // }

  // send data to the server if (current time - last send time) > send_interval_s
  return ((data_current.ts - data_last_sent.ts) > send_interval_s);
}

// Callback for server status changes.
function send_data(status) {
  // update last sent data (even on failure, so the next send attempt is not immediate)
  local power_manager_data=[];
  nv.data_sent = nv.data.top();
  
  if (status == SERVER_CONNECTED) {
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
      if (debug == true) server.log("Error: Server connected, but no success.");
    }
  }
  
  else {
    if (debug == true) server.log("Tried to connect to server to send data but failed.");
    power.enter_deep_sleep_failed("Sleeping after failing to connect to server for sending data.");
  }
  
  if (ship_and_store == true) {
    power.enter_deep_sleep_ship_store("Hardcoded ship and store mode active.");
  }
  else {
    // Sleep until next sensor sampling
    power.enter_deep_sleep_running("Finished sending JSON data.");
  }
}

// Callback for server status changes.
function send_loc(status) {
  if (status == SERVER_CONNECTED) {
    if (debug == true) server.log("Called send_loc function");
    // ok: send data
    // server.log(imp.scanwifinetworks());
    agent.send("location", {
      device = hardware.getdeviceid(),
      loc = imp.scanwifinetworks(),
      ssid = imp.getssid()
    });
    local success = server.flush(TIMEOUT_SERVER_S);
    if (success) {
    }
    
    else {
      if (debug == true) server.log("Error: Server connected, but no location success.");
    }
  }
  else {
    if (debug == true) server.log("Tried to connect to server to send location but failed.");
    power.enter_deep_sleep_failed("Sleeping after failing to connect to server for sending location.");
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

//0.1
//should return a string that can be written to a register
//needs some testing
function toHexStr(firstByte="0",secondByte="0"){
  return "\\x"+firstByte+secondByte;
}


function main() {
  // manual control of Wi-Fi state and other setup
  server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);

  // I could remove this, since, according to Hugo:
  // When you wake from an imp.deepsleep or server.sleep,
  // wifi is not up - there's no need to immediately disconnect.
  // You'd have to either explicitly connect (if you are using
  // RETURN_ON_ERROR) or perform an operation which requires
  // network (if you're using SUSPEND_ON_ERROR).
  // server.disconnect();
  // imp.onidle(function() {
  //   server.disconnect();
  // });
  
  if (debug == true) server.log("Device's unique id: " + hardware.getdeviceid());
  server.log("Device firmware version: " + imp.getsoftwareversion());
  server.log("Memory free: " + imp.getmemoryfree());
  // logDeviceOnline();
  
  
  // Configure i2c bus
  // This method configures the I²C clock speed and enables the port.
  hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

  if (debug == true) server.log("Device booted.");

  ///
  // Event handlers
  ///
  agent.on("location_request", function(data) {
    if (debug == true) server.log("Agent requested location information.");
    connect(send_loc, TIMEOUT_SERVER_S);
  });

  // Register the disconnection handler
  server.onunexpecteddisconnect(disconnectHandler);

  // hardware.pin1.configure("DIGITAL_IN_WAKEUP", function(){server.log("imp woken") });
  hardware.pin1.configure(DIGITAL_IN_WAKEUP, interruptPin);
  

  ///
  // End of event handlers
  ///
  
  // server.disconnect();
  if (ship_and_store == true) {
    power.enter_deep_sleep_ship_store("Hardcoded ship and store mode active.");
  }
  greenLed.configure();
  redLed.configure();
  blueLed.configure();
  // led.configure();
  soil.configure();
  solar.configure();
  source.configure();

  server.log("Memory free after configurations: " + imp.getmemoryfree());
  
  // Useless according to Hugo from Electric Imp
  // imp.setpowersave(true);
  imp.enableblinkup(false);
  // create non-volatile storage if it doesn't exist
  if (!("nv" in getroottable() && "data" in nv)) {
        nv<-{data = [], data_sent = null, running_state = true};  
  }
  
  
  // we have entered the running state
  nv.running_state = true;
  
  // Create PowerManager object
  powerManager <- PowerManager(hardware.i2c89);
  powerManager.changeBatteryMax();
  powerManager.sample();

  // Create HumidityTemperatureSensor object
  humidityTemperatureSensor <- HumidityTemperatureSensor();
  humidityTemperatureSensor.sample();

  
  
  // nv space is limited to 4kB and will not notify of failure
  // discard every second entry if over MAX entries
  // TODO: combine similar data points instead of discarding them
  if (nv.data.len() > NV_ENTRIES_MAX) {
    local i = 1;
    while(i < nv.data.len()) {
      nv.data.remove(i);
      i += 2;
    }
  }

  // store sensor data in non-volatile storage
  //0.1
  //testing or not
  if(runTest)
  {
      nv.data.push({
        ts = time(),
        t = humidityTemperatureSensor.temperature,
        h = humidityTemperatureSensor.humidity,
        l = solar.voltage(),
        m = soil.voltage(),
        b = source.voltage()
        testResults=unitTest()
      });
  }
  else
  {
        nv.data.push({
        ts = time(),
        t = humidityTemperatureSensor.temperature,
        h = humidityTemperatureSensor.humidity,
        l = solar.voltage(),
        m = soil.voltage(),
        b = source.voltage()
        });
  }
  

  //Send sensor data
  if (is_server_refresh_needed(nv.data_sent, nv.data.top())) {
    if (debug == true) server.log("Server refresh needed");
    connect(send_data, TIMEOUT_SERVER_S);
    

    
    // if (debug == true) server.log("Sending location information without prompting.");
    // connect(send_loc, TIMEOUT_SERVER_S);
  }

  // ///
  // all the important time-sensitive decisions based on current state go here
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
    
    
// Define a function to handle disconnections
 
function disconnectHandler(reason) {
  if (reason != SERVER_CONNECTED){
    if (debug == true) server.log("Unexpectedly lost wifi connection.");
    power.enter_deep_sleep_failed("Unexpectedly lost wifi connection.");
  }
}

//0.1
//added unit test here
function unitTest()
{

}



///
// End of functions
///

 
main();