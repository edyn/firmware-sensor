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
// const INTERVAL_SLEEP_MAX_S = 2419198; // maximum sleep allowed by Imp is ~28 days
const INTERVAL_SLEEP_MAX_S = 86400; // keep the maximum sleep at a day during development
const INTERVAL_SLEEP_SHIP_STORE_S = 2419198;
const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
const POLL_ITERATION_MAX = 100; // maximum number of iterations for sensor polling loop
const NV_ENTRIES_MAX = 40; // maximum NV entry space is about 55, based on testing
debug <- true; // How much logging do we want?
coding <- true; // Do you need live data right now?
demo <- false; // Should we send data really fast?
ship_and_store <- false; // Directly go to ship and store?

// offline logging
offline <- [];
const TZ_OFFSET = -25200; // 7 hours for PDT
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

if (debug == true) log("Device booted - code version 1.0.");
if (debug == true) log("Device's unique id: " + hardware.getdeviceid());

// Blue LED, active low
class led {
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
      led.on();
      imp.sleep(duration);
      led.off();
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
// The i2c object has the following member methods:

// i2c.configure(const) – configures the I²C clock speed, and enables the port
// i2c.disable() – disables the I²C bus
// i2c.read(integer, string, integer) – initiates an I²C read of N bytes from the specified base and sub-address
// i2c.readerror() – returns error code from last I²C read
// i2c.write(integer, string) – initiates an I²C write to the specified address
  
  _i2c  = null;
  _addr = null;
  static SA_REG_2 = "\x02";
  static SA_CHARGER_STATUS = "\x03";
  static SA_EXTERNAL_POWER = "\x04";
  static SA_NTC_WARNING = "\x05";
  static SA_REG_0 = "\x00";
  static SA_REG_1 = "\x01";
  
  charger_status = 0;
  reg_2 = 0;
  reg_0 = 0;
  reg_1 = 0;
  external_power = 0;
  ntc_warning = 0;
  // static SA_CHARGER_STATUS = impified_i2c_address.toString();
  
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

  // EVT wifi sensor can measure Solar panel voltage (PIN7)
  // and output voltage (PINB)
  // Once PIN7>PINB voltage & charging is enabled electricimp
  // needn’t be sleeping and control charging
  function sample() {
    // The transaction is initiated by the bus master with a START condition
    // The SMBus command code corresponds to the sub address pointer value
    // and will be written to the sub address pointer register in the LTC4156
    // Note: Imp I2C command values are strings with 
    // the \x escape character to indicate a hex value
    
    local iteration = 0;
    local word = 0x0;
    _i2c.write(_addr, SA_CHARGER_STATUS);
    do {
      // imp.sleep(0.1);
      word = _i2c.read(_addr, SA_CHARGER_STATUS, 1);
      // server.log(word);
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX) {
        if (debug == true) log("Polled 100 times and gave up.");
        break;
      }
    } while (word == null);
    // log("Charger status, etc.:");
    // charger_status = (word[0] & 0xe0) >> 5;
    charger_status = (word[0] & 0xff);
    // charger_status = word[0];
    if (debug == true) server.log(word[0]);
    
    
    iteration = 0;
    word = 0x0;
    // _i2c.write(_addr, SA_REG_2 + "\xFC");
    _i2c.write(_addr, SA_REG_2 + "\xF0");
    do {
      // imp.sleep(0.1);
      word = _i2c.read(_addr, SA_REG_2, 1);
      // server.log(word);
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX) {
        if (debug == true) log("Polled 100 times and gave up.");
        break;
      }
    } while (word == null);
    // log("Charge current, float voltage, c/x detection:");
    if (debug == true) server.log(word[0]);
    // charge_current = (word[0] & 0xf0) >> 4;
    reg_2 = (word[0] & 0xff);
    
    iteration = 0;
    word = 0x0;
    _i2c.write(_addr, SA_REG_0);
    do {
      // imp.sleep(0.1);
      word = _i2c.read(_addr, SA_REG_0, 1);
      // server.log(word);
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX) {
        if (debug == true) log("Polled 100 times and gave up.");
        break;
      }
    } while (word == null);
    // log("Charge current, float voltage, c/x detection:");
    if (debug == true) server.log(word[0]);
    // charge_current = (word[0] & 0xf0) >> 4;
    reg_0 = (word[0] & 0xff);
    
    iteration = 0;
    word = 0x0;
    _i2c.write(_addr, SA_REG_1);
    do {
      // imp.sleep(0.1);
      word = _i2c.read(_addr, SA_REG_1, 1);
      // server.log(word);
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX) {
        if (debug == true) log("Polled 100 times and gave up.");
        break;
      }
    } while (word == null);
    // log("Charge current, float voltage, c/x detection:");
    if (debug == true) server.log(word[0]);
    // charge_current = (word[0] & 0xf0) >> 4;
    reg_1 = (word[0] & 0xff);

    // external power
    iteration = 0;
    word = 0x0;
    _i2c.write(_addr, SA_EXTERNAL_POWER);
    do {
      // imp.sleep(0.1);
      word = _i2c.read(_addr, SA_EXTERNAL_POWER, 1);
      // server.log(word);
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX) {
        if (debug == true) log("Polled 100 times and gave up.");
        break;
      }
    } while (word == null);
    // log("Charge current, float voltage, c/x detection:");
    if (debug == true) server.log(word[0]);
    external_power = (word[0] & 0xff);
    
    // ntc warning
    iteration = 0;
    word = 0x0;
    _i2c.write(_addr, SA_NTC_WARNING);
    do {
      // imp.sleep(0.1);
      word = _i2c.read(_addr, SA_NTC_WARNING, 1);
      // server.log(word);
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX) {
        if (debug == true) log("Polled 100 times and gave up.");
        break;
      }
    } while (word == null);
    // log("Charge current, float voltage, c/x detection:");
    if (debug == true) server.log(word[0]);
    ntc_warning = (word[0] & 0xff);

    // server.log(output);
    // _i2c.readerror();
    // Wait for the sensor to finish the reading
    // while ((_i2c.read(_addr, SA_CHARGER_STATUS + "", 1)[0] & 0x80) == 0x80) {
    //  log(_i2c.read(_addr, SA_CHARGER_STATUS + "", 1));
    // }
    // timeout
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
  
  function sample() {
    local humidity_raw, temperature_raw, iteration = 0;
    local data = [0x0, 0x0];
    
    // Measurement Request - wakes the sensor and initiates a measurement
    if (debug == true) server.log("Sampling temperature");
    if (debug == true) server.log(i2c.write(ADDRESS, SUB_ADDR_TEMP));
    // if (i2c.write(ADDRESS, SUB_ADDR_TEMP) == null)
    //  return -1;

    // Data Fetch - poll until the 'stale data' status bit is 0
    do {
      imp.sleep(0.1);
      data = i2c.read(ADDRESS, SUB_ADDR_TEMP, 2);
      if (debug == true) server.log("Read attempt");
      
      // timeout
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX)
        break;
    } while (data == null);
    
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
    temperature_raw = (data[0] << 8) + (data[1] & 0xfc);
    temperature = temperature_raw * 175.72 / 65536.0 - 46.85;
    
    
    iteration = 0;
    data = [0x0, 0x0];
    // Measurement Request - wakes the sensor and initiates a measurement
    if (debug == true) server.log("Sampling humidity");
    if (debug == true) server.log(i2c.write(ADDRESS, SUB_ADDR_HUMID));
    // Data Fetch - poll until the 'stale data' status bit is 0
    do {
      imp.sleep(0.1);
      data = i2c.read(ADDRESS, SUB_ADDR_HUMID, 2);
      if (debug == true) server.log("Read attempt");
      
      // timeout
      iteration += 1;
      if (iteration > POLL_ITERATION_MAX)
        break;
    } while (data == null);
    
    humidity_raw = (data[0] << 8) + (data[1] & 0xfc);
    humidity = humidity_raw * 125.0 / 65536.0 - 6.0;
  }
}

// Configure i2c bus
// This method configures the I²C clock speed and enables the port.
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

// LTC4156 battery charger 0x12 
// server.log(hardware.i2c89.write(0x12, "\x03"));
// server.log(hardware.i2c89.read(0x12, "\x03", 1)[0]);
// server.log(hardware.i2c89.write(0x12, "\x02"));
// server.log(hardware.i2c89.read(0x12, "\x02", 1)[0]);

// HTU21D ambient humidity sensor 0x80
// server.log(hardware.i2c89.write(0x80, ""));

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

function onConnectedTimeout(state) {
  //If we're connected...
  if (state == SERVER_CONNECTED) 
  {
    // ...do something
    if (debug == true) log("After allowing a chance to blinkup, succesfully connected to server.");
    main();
  } 
  else 
  {
    // Otherwise, do something else
    if (debug == true) log("Gave a chance to blink up, then tried to connect to server but failed.");
    power.enter_deep_sleep_ship_store("Conservatively going into ship and store mode after failling to connect to server.");
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

alreadyPressed <- false;
// hardware.pin1.configure("DIGITAL_IN_WAKEUP", function(){server.log("imp woken") });
hardware.pin1.configure(DIGITAL_IN_WAKEUP, function(){
  alreadyPressed = true;
  if (debug == true) log("Button pressed");
  led.blink(0.1, 10);
  // Enable blinkup for 30s
  imp.enableblinkup(true);
  imp.sleep(30);
  imp.enableblinkup(false);
  led.blink(0.1, 10);
  imp.setwificonfiguration("doesntexist", "lalala");
  connect(onConnectedTimeout, 20);
  imp.sleep(21);
  alreadyPressed = false;
  // server.connect(send_data, TIMEOUT_SERVER_S);
});

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
    if (debug == true) log("Deep sleep (running) call because: "+reason);
    imp.wakeup(5,function() {
      imp.onidle(function() {
        if (debug == true) log("Starting deep sleep (running).");
        if (debug == true) log("Note that subsequent 'sensing' wakes won't log here.");
        if (debug == true) log("The next wake to log will be the 'data transmission' wake.");
        server.sleepfor(INTERVAL_SENSOR_SAMPLE_S);
      });
    });
  }
  
  function enter_deep_sleep_ship_store(reason) {
    // nv.running_state = false;
    //Old version before Electric Imp's sleeping fix
    //imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
    //Implementing Electric Imp's sleeping fix
    led.blink(1.0, 2);
    if (debug == true) log("Deep sleep (storage) call because: "+reason)
    imp.wakeup(0.5,function() {
      imp.onidle(function() {
        if (debug == true) log("Starting deep sleep (ship and store).");
        server.sleepfor(INTERVAL_SLEEP_SHIP_STORE_S);
      });
    });
  }
}


// return true iff the collected data should be sent to the server
function is_server_refresh_needed(data_last_sent, data_current) {
  // first boot, always send
  if (data_last_sent == null)     return true;

  local send_interval_s = 0;
  
  local higher_frequency = 0;
  local high_frequency = 0;
  local medium_frequency = 0;
  local low_frequency = 0;
  local lower_frequency = 0;

  if (debug == true) log("Debug mode.");

  if (demo == true) {
    log("Demo mode.");
    higher_frequency = 60*0;
    high_frequency = 60*1;
    medium_frequency = 60*2;
    low_frequency = 60*5;
    lower_frequency = 60*10;
    lowest_frequency = 60*30;
  }

  // Live coding settings
  else if (demo == false && coding == true) {
    log("Coding mode");
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
    high_frequency = 60*20;
    medium_frequency = 60*45;
    low_frequency = 60*60;
    lower_frequency = 60*120;
    lowest_frequency = 60*720;
  }

  // send updates more often when the battery is full
  if (data_current.b > 3.4)      send_interval_s = higher_frequency;   // battery overcharge
  else if (data_current.b > 3.35) send_interval_s = high_frequency;   // battery full
  else if (data_current.b > 3.3) send_interval_s = medium_frequency;  // battery high
  else if (data_current.b > 3.25) send_interval_s = low_frequency;  // battery medium
  else if (data_current.b > 3.2) {
    send_interval_s = lower_frequency; // battery low
    log("Low battery");
  }
  else if (data_current.b > 3.12) {
    send_interval_s = lowest_frequency;
    log("Near-critical battery");
  }
  else if (data_current.b > 3.0) return false;             // battery critical
  else {
    // emergency shutoff workaround to prevent the Imp 'red light bricked' state
    power.enter_deep_sleep_ship_store("Emergency battery levels.");
  }

  // send updates more often when data has changed frequently and battery life is good
  if (data_current.b > 3.25
    && (math.fabs(data_last_sent.t - data_current.t) > 5.0
      || math.fabs(data_last_sent.h - data_current.h) > 5.0
      || math.fabs(data_last_sent.l - data_current.l) > 50.0
      || math.fabs(data_last_sent.m - data_current.m) > 0.2
      || math.fabs(data_last_sent.b - data_current.b) > 0.2)) {
    if (debug == true) log("Data is changing quickly, so send updates more often.");
    send_interval_s /= 4;
  }

  // send data to the server if (current time - last send time) > send_interval_s
  return ((data_current.ts - data_last_sent.ts) > send_interval_s);
}

// Callback for server status changes.
function send_data(status) {
  // update last sent data (even on failure, so the next send attempt is not immediate)
  nv.data_sent = nv.data.top();
  
  if (status == SERVER_CONNECTED) {
    // ok: send data
    // server.log(imp.scanwifinetworks());
    if (debug == true) log("Connected to server.");
    agent.send("data", { device = hardware.getdeviceid(), data = nv.data} ); // TODO: send error codes
    local success = server.flush(TIMEOUT_SERVER_S);
    if (success) {
      // update last sent data (even on failure, so the next send attempt is not immediate)
      nv.data_sent = nv.data.top();
      
      // clear non-volatile storage
      nv.data.clear();
    }
    
    else {
      if (debug == true) log("Error: Server connected, but no success.");
    }
  }
  
  else {
    if (debug == true) log("Error: Server connection failed.");
    power.enter_deep_sleep_ship_store("Conservatively going into ship and store mode after data send failure.");
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
function send_loc(state) {
  if (debug == true) log("Called send_loc function");
  // ok: send data
  // server.log(imp.scanwifinetworks());
  agent.send("location", { device = hardware.getdeviceid(), loc = imp.scanwifinetworks(), ssid = imp.getssid() } );
  local success = server.flush(TIMEOUT_SERVER_S);
  if (success) {
  }
  
  else {
    if (debug == true) log("Error: Server connected, but no location success.");
  }
}

function main() {
  log("Device firmware version: " + imp.getsoftwareversion());
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
  //  server.disconnect();
  // });
  server.disconnect();
  led.configure();
  soil.configure();
  solar.configure();
  source.configure();
  
  // Useless according to Hugo from Electric Imp
  // imp.setpowersave(true);
  imp.enableblinkup(false);
  
  // create non-volatile storage if it doesn't exist
  if (!("nv" in getroottable() && "data" in nv)) {
    nv <- { data = [], data_sent = null, running_state = true };
  }
  
  // we have entered the running state
  nv.running_state = true;
  
  // Create PowerManager object
  powerManager <- PowerManager(hardware.i2c89);
  powerManager.sample();

  // Create HumidityTemperatureSensor object
  humidityTemperatureSensor <- HumidityTemperatureSensor();
  humidityTemperatureSensor.sample();

  // nv space is limited to 4kB and will not notify of failure
  // discard every third entry if over MAX entries
  // TODO: combine similar data points instead of discarding them
  if (nv.data.len() > NV_ENTRIES_MAX) {
    local i = 1;
    while(i < nv.data.len()) {
      nv.data.remove(i);
      i += 2;
    }
  }

  // store sensor data in non-volatile storage
  nv.data.push({
    ts = time(),
    t = humidityTemperatureSensor.temperature,
    h = humidityTemperatureSensor.humidity,
    l = solar.voltage(),
    m = soil.voltage(),
    b = source.voltage(),
    REG3 = powerManager.charger_status,
    REG2 = powerManager.reg_2,
    REG0 = powerManager.reg_0,
    REG1 = powerManager.reg_1,
    REG5 = powerManager.ntc_warning,
    REG4 = powerManager.external_power
  });

  //Send sensor data
  if (is_server_refresh_needed(nv.data_sent, nv.data.top())) {
    if (server.isconnected()) {
      if (debug == true) log("Server refresh needed and server connected");
      // already connected (first boot?). send data.
      send_data(SERVER_CONNECTED);
      if (debug == true) log("Sending location information without prompting.");
      send_loc(SERVER_CONNECTED);
    }
    
    else {
      if (debug == true) log("Server refresh needed but need to connect first");
      // connect first then send data.
      server.connect(send_data, TIMEOUT_SERVER_S);
    }
  }
  
  else {
    log("Not time to send");
    if (ship_and_store == true) {
      power.enter_deep_sleep_ship_store("Hardcoded ship and store mode active.");
    }
    else {
      // not time to send. sleep until next sensor sampling.
      power.enter_deep_sleep_running("Not time yet");
    }
  }
  
}

agent.on("location_request", function(data) {
  if (debug == true) log("Agent requested location information.");
  connect(send_loc, TIMEOUT_SERVER_S);
});

local attemptNumber = 0;
if (ship_and_store == true) {
  power.enter_deep_sleep_ship_store("Hardcoded ship and store mode active.");
}

// Define a function to handle disconnections
 
function disconnectHandler(reason)
{
  if (reason != SERVER_CONNECTED)
  {
    power.enter_deep_sleep_ship_store("Lost wifi connection.");
  }
}
 
// Register the disconnection handler
 
server.onunexpecteddisconnect(disconnectHandler);

main();
