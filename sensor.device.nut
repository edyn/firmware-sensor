////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
//
// Imp Device code collects sensor data and sends it to
// the Imp Cloud. In between sensor samplings, the device
// will remain in deep sleep. To conserve power, the device
// does not send data to the server each time it samples.
// Samples are stored and a buffer, and sent based with
// varying frequency based on battery life and data delta.
// If there was a wifi communication error, the device will
// resume after a timeout. 
//
// TODO:
// - need ability to reset (magnetic reset, or power switch)
// - merge similar consecutive data points
// - return error data (i2c sensor error, etc) to host
// - interleave sensor sampling to reduce awake time
////////////////////////////////////////////////////////////

const INTERVAL_SENSOR_SAMPLE_S = 60; // sample sensors this often
// const INTERVAL_SLEEP_MAX_S = 2419198; // maximum sleep allowed by Imp is ~28 days
const INTERVAL_SLEEP_MAX_S = 86400; // keep the maximum sleep at a day during development
const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
const POLL_ITERATION_MAX = 100; // maximum number of iterations for sensor polling loop
const NV_ENTRIES_MAX = 40; // maximum NV entry space is about 55, based on testing

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

log("Device booted.");

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

// Battery voltage sensor
class battery {
    static pin = hardware.pinB;

    function configure() {
        pin.configure(ANALOG_IN);
    }
    
    function voltage() {
        // measures one half voltage divider, multiply by 2 to get the actual
        return 2.0 * (pin.read()/65536.0) * hardware.voltage();
    }
}

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

// Power management
class power {
    function enter_deep_sleep_running(reason) {
        //Old version before Electric Imp's sleeping fix
        //imp.deepsleepfor(INTERVAL_SENSOR_SAMPLE_S);
        //Implementing Electric Imp's sleeping fix
        log("Deep sleep (running) call because: "+reason);
        imp.wakeup(1,function() {
            imp.onidle(function() {
                log("Starting deep sleep (running).");
                // server.disconnect();
                // imp.deepsleepfor(INTERVAL_SENSOR_SAMPLE_S);
                server.sleepfor(INTERVAL_SENSOR_SAMPLE_S);
            });
        });
    }
    
    function enter_deep_sleep_storage(reason) {
        nv.running_state = false;
        //Old version before Electric Imp's sleeping fix
        //imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
        //Implementing Electric Imp's sleeping fix
        log("Deep sleep (storage) call because: "+reason)
        imp.wakeup(1,function() {
            imp.onidle(function() {
                log("Starting deep sleep (running).");
                // server.disconnect();
                // imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
                server.sleepfor(INTERVAL_SLEEP_MAX_S);
            });
        });
    }
}

////////////////////////////////////////////////////////////
// TSL2560 light sensor
////////////////////////////////////////////////////////////
class sensor_tsl2560 {
    static ADDRESS = 0x72; // = 0x39 << 1
    static CMD_PWR_ON = "\x80\x03";
    static CMD_PWR_OFF = "\x80\x00";
    static CMD_TIMING_GAIN_HI_INT_402 = "\x81\x12";
    static CMD_TIMING_GAIN_LO_INT_402 = "\x81\x02";
    
    static CMD_READ_WORD_CH0 = "\xAC"; // sensitive to visible + infrared
    static CMD_READ_WORD_CH1 = "\xAE"; // sensitive to infrared

    static i2c = hardware.i2c89;
    lux = 0.0;

    constructor() {
        i2c.configure(CLOCK_SPEED_400_KHZ);
    }

    function calculate_lux(ch0, ch1)
    {
        // C code is available that does not use floating point.
        
        // Channel 0 is sensitive to visible and infrared
        // Channel 1 is sensitive to mostly infrared
        
        // The calcualtion below is to filter out IR lux, but is not needed for this application
        
        // When ch0 is saturated, lux will appear to decrease when actaully increasing.
        
        /*
        ch0 = ch0.tofloat();
        ch1 = ch1.tofloat();
        local ratio = ch1/ch0;
        
        if (ratio < 0)          lux = 0;
        else if (ratio <= 0.50) lux = 0.0304*ch0 - 0.062*ch0*math.pow(ratio,1.4); 
        else if (ratio <= 0.61) lux = 0.0224*ch0 - 0.031*ch1;
        else if (ratio <= 0.80) lux = 0.0128*ch0 - 0.0153*ch1;
        else if (ratio <= 1.30) lux = 0.00146*ch0 - 0.00112*ch1;
        else                    lux = 0;
        */
        
        // http://www.apogeeinstruments.com/conversion-ppf-to-lux/
        // 16X multiplier to account for low gain setting
        return 16 * 0.0304 * ch0.tofloat();
    }

    function sample() {
        local data_ch0 = 0, data_ch1 = 0, iteration = 0;

        if (i2c.write(ADDRESS, CMD_TIMING_GAIN_LO_INT_402) == null)
            return -1;
        
        if (i2c.write(ADDRESS, CMD_PWR_ON) == null)
            return -1;

        // Conversion takes 402ms.
        // To optimize, other sensor reading may be done in this time.
        imp.sleep(0.403);
        
        // An interrupt pin is provided, but the Imp has no pin interrupts
        do {
            local ch0 = i2c.read(ADDRESS, CMD_READ_WORD_CH0, 2);
            local ch1 = i2c.read(ADDRESS, CMD_READ_WORD_CH1, 2);
            if (ch0 == null || ch1 == null)
                break;
            
            data_ch0 = (ch0[1] << 8) | ch0[0];
            data_ch1 = (ch1[1] << 8) | ch1[0];

            // timeout
            iteration += 1;
            if (iteration > POLL_ITERATION_MAX)
                break;
        } while(data_ch0 == 0 || data_ch1 == 0);
        
        if (i2c.write(ADDRESS, CMD_PWR_OFF) == null)
            return -1;
            
        lux = calculate_lux(data_ch0, data_ch1);
    }
}

////////////////////////////////////////////////////////////
// HYT221 temperature and humidity sensor
// 4 byte data format: cshhhhhh hhhhhhhh tttttttt ttttttuu
// c - command mode bit
// s - stale data status bit
// s - stale data status bit
// h - humidity data bit
// t - temperature data bit
// u - unused bit
////////////////////////////////////////////////////////////
class sensor_hyt221 {
    static ADDRESS = 0x50; // = 0x28 << 1
    static COMMAND_MODE_BIT = 0x80;
    static STATUS_STALE_BIT = 0x40;
    
    static i2c = hardware.i2c89;
    humidity = 0.0;
    temperature = 0.0;

    constructor() {
        i2c.configure(CLOCK_SPEED_400_KHZ);
    }
    
    function sample() {
        local is_data_stale, humidity_raw, temperature_raw, iteration = 0;
        
        // Measurement Request - wakes the sensor and initiates a measurement
        if (i2c.write(ADDRESS, "") == null)
            return -1;

        // Data Fetch - poll until the 'stale data' status bit is 0
        do {
            local data = i2c.read(ADDRESS, "", 4);
            if (data == null)
                return -1;
            
            is_data_stale = data[0] & STATUS_STALE_BIT;
            humidity_raw = 0x3FFF & ((data[0] << 8) | data[1]);
            temperature_raw = (data[2] << 6) | (data[3] >> 2);

            // timeout
            iteration += 1;
            if (iteration > POLL_ITERATION_MAX)
                break;
        } while (is_data_stale);

        // Convert from raw data to Percent Relative Humidity and Degrees Celsius
        //local humidity = 100.0 / pow(2,14) * humidity_raw;
        //local temperature = 165.0 / pow(2,14) * temperature_raw - 40;
        humidity = humidity_raw / 163.83;
        temperature = temperature_raw / 99.2909 - 40;
    }
}

function magnetic_switch_activated() {
    if (soil.voltage() > 2.0) {
        // soil probe is shorted
        
        // Flash blue led for 1s 3 times
        led.blink(1.0, 3);
        
        // deep sleep (storage state)
        power.enter_deep_sleep_storage("magnetic switch activated");
    } else {
        // Flash blue led for 0.1s 10 times
        led.blink(0.1, 10);

        // Enable blinkup for 30s
        imp.enableblinkup(true);
        
        // Old method
        // imp.sleep(30);
        // imp.enableblinkup(false);
        
        // Method recommended by Hugo from Electric Imp
        imp.wakeup(30, function() { imp.enableblinkup(false); });
    }
}

// return true iff the collected data should be sent to the server
function is_server_refresh_needed(data_last_sent, data_current) {
    // first boot, always send
    if (data_last_sent == null)     return true;

    local send_interval_s = 0;

    // send updates more often when the battery is full
    if (data_current.b >= 4.3)      send_interval_s = 60*0;   // battery overcharge
    
    // DEBUG settings (toggle comment with below)
    else if (data_current.b >= 4.1) send_interval_s = 60*5;   // battery full
    else if (data_current.b >= 3.9) send_interval_s = 60*5;  // battery high
    else if (data_current.b >= 3.7) send_interval_s = 60*5;  // battery nominal
    
    // Production settings (toggle comment with above)
    // else if (data_current.b >= 4.1) send_interval_s = 60*5;   // battery full
    // else if (data_current.b >= 3.9) send_interval_s = 60*20;  // battery high
    // else if (data_current.b >= 3.7) send_interval_s = 60*60;  // battery nominal
    
    else if (data_current.b >= 3.6) send_interval_s = 60*120; // battery low
    else if (data_current.b >= 3.5) return false;             // battery critical
    else {
        // emergency shutoff workaround to prevent the Imp 'red light bricked' state
        power.enter_deep_sleep_storage("emergency battery levels");
    }

    // send updates more often when data has changed frequently and battery life is good
    if (data_current.b >= 3.7
        && (math.fabs(data_last_sent.t - data_current.t) > 5.0
          || math.fabs(data_last_sent.h - data_current.h) > 5.0
          || math.fabs(data_last_sent.l - data_current.l) > 50.0
          || math.fabs(data_last_sent.m - data_current.m) > 0.2
          || math.fabs(data_last_sent.b - data_current.b) > 0.2))
        send_interval_s /= 4;

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
        agent.send("data", { device = hardware.getimpeeid(), data = nv.data} ); // TODO: send error codes
        log("connected 266");
        local success = server.flush(TIMEOUT_SERVER_S);
        if (success) {
            // update last sent data (even on failure, so the next send attempt is not immediate)
            nv.data_sent = nv.data.top();
            
            // clear non-volatile storage
            nv.data.clear();
        } else {
            // error: blink led
            led.blink(0.1,5);
            log("Error: Server connected, but no success.");
        }
    } else {
        // error: blink led
        led.blink(0.3,3);
        log("Error: Server is not connected.");
    }
    
    // Sleep until next sensor sampling
    power.enter_deep_sleep_running("Sleep until next sensor sampling");
}

// Callback for server status changes.
function send_loc() {
    log("Called send_loc function");
    // ok: send data
    // server.log(imp.scanwifinetworks());
    agent.send("location", { device = hardware.getimpeeid(), loc = imp.scanwifinetworks()} );
    local success = server.flush(TIMEOUT_SERVER_S);
    if (success) {
    } else {
    log("Error: Server connected, but no location success.");
    }
}

function main() {
    log("Device firmware version: " + imp.getsoftwareversion());
    // manual control of Wi-Fi state and other setup
    server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, TIMEOUT_SERVER_S);
    server.disconnect();
    // Removing this since, according to Hugo:
    // When you wake from an imp.deepsleep or server.sleep,
    // wifi is not up - there's no need to immediately disconnect.
    // You'd have to either explicitly connect (if you are using
    // RETURN_ON_ERROR) or perform an operation which requires
    // network (if you're using SUSPEND_ON_ERROR).
    // server.disconnect();
    
    // Useless according to Hugo from Electric Imp
    // imp.setpowersave(true);
    imp.enableblinkup(false);
    
    // create non-volatile storage if it doesn't exist
    if (!("nv" in getroottable() && "data" in nv)) {
        nv <- { data = [], data_sent = null, running_state = true };
    }
    
    led.configure();
    battery.configure();
    soil.configure();
    
    // Configure wakeup pin (high - magnetic switch activated, low - otherwise)
    // Callback is not preemptive so read the pin state manually
    magnetic_wakeup <- hardware.pin1;
    magnetic_wakeup.configure(DIGITAL_IN_WAKEUP);

    // user did not wake the device and not running, go back to sleep
    if (magnetic_wakeup.read() == 0 && nv.running_state == false) {
        power.enter_deep_sleep_storage("User didn't wake");
    }
    
    // user activated wake: blinkup if soil probe not shorted, otherwise sleep
    if (magnetic_wakeup.read() == 1) {
        magnetic_switch_activated();
    }
    
    // enable the magnetic switch callback for detection while gathering sensor data or wifi operations
    magnetic_wakeup.configure(DIGITAL_IN_WAKEUP, magnetic_switch_activated);
    
    // we have entered the running state
    nv.running_state = true;
    led.blink(0.001);

    // Init and sample all sensors
    temperature_humidity <- sensor_hyt221();
    temperature_humidity.sample();
    ambient_light <- sensor_tsl2560();
    ambient_light.sample();

    // nv space is limited to 4kB and will not notify of failure
    // discard every other entry if over MAX entries
    // TODO: combine similar data points instead of discarding them
    if (nv.data.len() > NV_ENTRIES_MAX) {
        local i = 1;
        while(i < nv.data.len()) {
            nv.data.remove(i);
            i += 1;
        }
    }

    // store sensor data in non-volatile storage
    nv.data.push({
        ts = time(),
        t = temperature_humidity.temperature,
        h = temperature_humidity.humidity,
        l = ambient_light.lux,
        m = soil.voltage(),
        b = battery.voltage()
    });

    //Send sensor data
    if (is_server_refresh_needed(nv.data_sent, nv.data.top())) {
        if (server.isconnected()) {
            // already connected (first boot?). send data.
            send_data(SERVER_CONNECTED);
        } else {
            // connect first then send data.
            server.connect(send_data, TIMEOUT_SERVER_S);
        }
    } else {
        // not time to send. sleep until next sensor sampling.
        power.enter_deep_sleep_running("Not time yet");
    }
    
}

agent.on("location_request", function(data) {
  log("Agent requested location information.");
  send_loc();
});

main();
