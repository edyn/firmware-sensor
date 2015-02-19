// The following code provides minimal factory firmware for the
// Factory Blinkup Fixture.

// Here, the Factory BlinkUp Fixture is an old PCBA with an LED on pin D.
// Every ten seconds the Fixture will start the BlinkUp procedure automatically. 

// The target device will automatically and immediately be blessed as soon as
// it runs this code.

// The LED on the device’s imp card (not the Factory BlinkUp Fixture) will
// turn solid green indicating pass/bless, or turn solid red indicating
// fail/no blessing.

// The webhooks will then be notified of the blessing event
// and take further actions.

const SSID = "Edyn Front"; 
const PASSWORD = "edyn1234"; 
// const FIXTURE_MAC = "0c2a690226d2";  // First one Paul picked
const FIXTURE_MAC = "0c2a690223d3"; // First one Jason picked
// const FIXTURE_MAC = "0c2a69000104"; // April
const INTERVAL_SLEEP_SHIP_STORE_S = 2419198;

mac <- imp.getmacaddress(); 
impeeid <- hardware.getimpeeid(); 

// Power management
class power {
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
        // server.disconnect();
        // imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
        server.sleepfor(INTERVAL_SLEEP_SHIP_STORE_S);
      });
    });
  }
}
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
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
led.configure();
// Power management
class power {  
  function enter_deep_sleep_ship_store(reason) {
    // nv.running_state = false;
    //Old version before Electric Imp's sleeping fix
    //imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
    //Implementing Electric Imp's sleeping fix
    led.blink(1.0, 2);
    server.log("Deep sleep (storage) call because: "+reason)
    imp.wakeup(0.5,function() {
      imp.onidle(function() {
        server.log("Starting deep sleep (ship and store).");
        // server.disconnect();
        // imp.deepsleepfor(INTERVAL_SLEEP_MAX_S);
        server.sleepfor(INTERVAL_SLEEP_SHIP_STORE_S);
      });
    });
  }
}


alreadyPressed <- false;
// hardware.pin1.configure("DIGITAL_IN_WAKEUP", function(){server.log("imp woken") });
hardware.pin1.configure(DIGITAL_IN_WAKEUP, function(){
  alreadyPressed = true;
  server.log("Button pressed");
  led.blink(0.1, 10);
  // Enable blinkup for 30s
  imp.enableblinkup(true);
  imp.sleep(40);
  imp.enableblinkup(false);
  led.blink(0.1, 10);
  imp.setwificonfiguration("doesntexist", "lalala");
  power.enter_deep_sleep_ship_store("Conservatively going into ship and store mode after failling to connect to server.");
  alreadyPressed = false;
  // server.connect(send_data, TIMEOUT_SERVER_S);
});

function factoryblinkup() {
    imp.wakeup(10, factoryblinkup);
    server.factoryblinkup(SSID, PASSWORD, hardware.pinD, 0); 
}
 
function factorybless() {
    server.bless(true, function(bless_success) { 
        server.log("Blessing " + (bless_success ? "PASSED" : "FAILED")); 
        agent.send("testresult", {device_id = impeeid, mac = mac, success = bless_success});
        if (bless_success) {
          imp.clearconfiguration();
          power.enter_deep_sleep_ship_store("Blessing complete");
        }
    }); 
}
 
if (imp.getssid() != SSID) return; // Don't run the factory code if not in the factory
if (mac == FIXTURE_MAC) {
    factoryblinkup();
} else {
    factorybless();
}