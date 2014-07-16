////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Valve
//
// Imp device connects to wifi, reports status (id, battery,
// valve state, etc), and checks for new valve actions on the
// Imp cloud. The device then checks for scheduled actions
// and performs them if it is time. If an action resulted in
// a valve state change, the device restarts to send an update.
//
// TODO:
// - push improvements back to probe code
// - store schedule internally so that valve will still work
//   with no wifi connection
////////////////////////////////////////////////////////////

const INTERVAL_VALVE_OPEN_MAX_S = 7200; // 2hr limit on keeping valve open
const INTERVAL_SLEEP_MAX_S = 2419198; // maximum sleep allowed by Imp is ~28 days
const TIMEOUT_SERVER_S = 20; // timeout for wifi connect and send
const VALVE_OPERATION_BATTERY_MIN_V = 3.7; // battery must be above this threshold to open
const BATTERY_CRITICAL_V = 3.5;

function min(a, b) {
    return (a < b) ? a : b;
}

function max(a, b) {
    return (a > b) ? a : b;
}

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

// Power management
class power {
    function enter_deep_sleep_running(sleep_time_s) {
        nv.running_state = true;
        server.disconnect();
        imp.onidle(function() {
          imp.deepsleepfor(sleep_time_s);
        });
    }
    
    function enter_deep_sleep_storage() {
        nv.running_state = false;
        server.disconnect();
        imp.onidle(function() {
          imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
        });
    }
}

// Handle the magnetic reed switch interaction
class magnetic_wake {
    static pin = hardware.pin1;
    
    function configure() {
        // Configure wakeup pin (high - magnetic switch activated, low - otherwise)
        pin.configure(DIGITAL_IN_WAKEUP);

        // user did not wake the device and not running, go back to sleep
        if (hardware.wakereason() != WAKEREASON_PIN1 && nv.running_state == false) {
            power.enter_deep_sleep_storage(); // does not return
        }
        
        // user activated wake: blinkup if soil probe not shorted, otherwise sleep
        if (hardware.wakereason() == WAKEREASON_PIN1) {
            magnetic_wake.callback();
        }
        
        // enable the magnetic switch callback for detection while gathering sensor data or wifi operations
        pin.configure(DIGITAL_IN_WAKEUP, magnetic_wake.callback);
    }
    
    function callback() {
        // Flash blue led for 0.1s 10 times
        led.blink(0.1, 10);

        // Enable blinkup for 30s. If switch activated during this time, sleep in storage state
        imp.enableblinkup(true);
        local start_time_s = time();
        while (time() - start_time_s < 30) {
            if (magnetic_wake.pin.read() == 1) {
                led.blink(5, 1);
                power.enter_deep_sleep_storage(); // does not return
            }
        }
        imp.enableblinkup(false);
    }
}

// Possible states for the valve to be in
enum valve_state {
    unknown = "unknown",
    close = "close",
    open = "open",
}

// Valve management
class valve {
    static enable = hardware.pin2;
    static forward = hardware.pin5;
    static reverse = hardware.pin6;

    function configure() {
        enable.configure(DIGITAL_OUT);
        forward.configure(DIGITAL_OUT);
        reverse.configure(DIGITAL_OUT);
        enable.write(0);
        forward.write(0);
        reverse.write(0);
    }
    
    function open() {
        // do not open the valve if battery voltage is too low
        if (battery.voltage() < VALVE_OPERATION_BATTERY_MIN_V) {
            return;
        }
        
        // pulse the enable and forward pins
        enable.write(1);
        imp.sleep(0.002); // 2ms
        forward.write(1);
        imp.sleep(0.050); // 50ms
        forward.write(0);
        enable.write(0);

        // update the valve state
        nv.valve_state = valve_state.open;
    }

    function close() {
        // pulse the enable and reverse pins
        enable.write(1);
        imp.sleep(0.002); // 2ms
        reverse.write(1);
        imp.sleep(0.050); // 50ms
        reverse.write(0);
        enable.write(0);
        
        // update the valve state
        nv.valve_state = valve_state.close;
    }

    function state() {
        return nv.valve_state;
    }
    
    function test() {
        led.on();
        valve.open();
        imp.sleep(5);
        led.off();
        valve.close();
        imp.wakeup(10, valve.test);
    }
}

// Fetch and handle actions from the server
class action {
    // Get request from server
    function fetch_action() {
        if (server.isconnected()) {
            // if we're already connected execute the callback
            action.handle_connect(SERVER_CONNECTED);
        } else {
            // otherwise, proceed as normal
            server.connect(action.handle_connect, TIMEOUT_SERVER_S);
        }
    }
    
    // Handle connection event and get action
    function handle_connect(status) {
        if (status == SERVER_CONNECTED) {
            // set up the response handler for the upcoming request
            agent.on("action_response", action.handle_action);
            
            // request an action (valve open/close) and send status to server 
            agent.send("action_request", {
                device_id = hardware.getdeviceid(), 
                battery_voltage = battery.voltage(), 
                time = time(), 
                valve_state = nv.valve_state,
            });
            
            // force call to handle_action if not triggered via action_response callback, due to server or link error
            imp.wakeup(1.0, action.handle_action);
        } else {
            // there was an error, force call to handle_action
            action.handle_action();
        }
    }
    
    // Handle the request
    function handle_action(request = null) {
        // disconnect before performing valve action
        server.flush(TIMEOUT_SERVER_S);
        server.disconnect();
        
        // save the valve state
        local valve_state_previous = valve.state();

        // schledule valve action (override any existing scheduled action)
        if ("action" in request) {
            if (request.action == valve_state.open) {
                nv.schedule = {
                    action = request.action,
                    time = request.time,
                    duration = min(request.duration, INTERVAL_VALVE_OPEN_MAX_S),
                };
            } else if (request.action == valve_state.close) {
                nv.schedule = {
                    action = request.action,
                    time = request.time,
                };
            }
        }

        // handle the scheduled valve action
        if ("action" in nv.schedule) {
            // check if it is time to perform the action
            if (nv.schedule.time <= time()) {
                if (nv.schedule.action == valve_state.open) {
                    // open the valve and schedule when to close the valve
                    valve.open();
                    nv.schedule = {
                        action = valve_state.close,
                        time = time() + nv.schedule.duration,
                    };
                } else if (nv.schedule.action == valve_state.close) {
                    // close the valve and clear the schedule
                    valve.close();
                    nv.schedule = {};
                }
            }
        }
        
        // if valve state is unknown, close it
        if (valve.state() == valve_state.unknown) {
            valve.close();
        }

        // the valve has changed state. restart to send an update now
        // instead of waiting for the next regular update interval.
        // restarting is the easiest way since we've already disconnected
        if (valve.state() != valve_state_previous) {
            power.enter_deep_sleep_running(0);
        }

        // set the running deep sleep interval based on battery voltage
        local interval_s = 0;
        local v = battery.voltage();
        if (v >= 4.3)      interval_s = 60*1;    // battery overcharge
        else if (v >= 4.1) interval_s = 60*5;    // battery full
        else if (v >= 3.9) interval_s = 60*20;   // battery high
        else if (v >= 3.7) interval_s = 60*60*1; // battery nominal
        else if (v >= 3.6) interval_s = 60*60*2; // battery low
        else               interval_s = 60*60*4; // battery critical

        // if there is a scheduled action pending, ensure we wake up in time for it
        if ("action" in nv.schedule) {
            interval_s = min(interval_s, nv.schedule.time - time());
            interval_s = max(interval_s, 0);
        }
        
        // deep sleep for the specified interval
        power.enter_deep_sleep_running(interval_s);
    }
}

// runs on every wake
function main() {
    // manual control of Wi-Fi state and other setup
    server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_FOR_ACK, TIMEOUT_SERVER_S);
    server.disconnect();
    imp.setpowersave(true);
    imp.enableblinkup(false);
    
    // create non-volatile storage if it doesn't exist
    if (!("nv" in getroottable() && "valve_state" in nv)) {
        nv <- { valve_state = valve_state.unknown, running_state = true, schedule = {} };
    }
    
    // configure devices
    led.configure();
    magnetic_wake.configure();
    battery.configure();
    valve.configure();
    
    // we have entered the running state
    nv.running_state = true;
    led.blink(0.001);
    
    // emergency shutoff. workaround to prevent the Imp 'red light bricked' state
    if (battery.voltage() <= BATTERY_CRITICAL_V) {
        // close valve if it is not closed
        if (valve.state != valve_state.close) {
            valve.close();
        }
        power.enter_deep_sleep_storage(); // does not return
    }

    //valve.test();
    action.fetch_action();
}

main();
