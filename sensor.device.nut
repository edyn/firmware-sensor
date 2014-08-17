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

log("Device booted - code version 1.0.");
log("Device's unique id: " + hardware.getdeviceid());

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
	static SA_CHARGER_STATUS = "\x03";
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
    // local reg3 = 0x03;
    // server.log(reg3);
    // local impified_i2c_address = reg3 << 1;
    // server.log(impified_i2c_address);
	
	 // server.log(SA_CHARGER_STATUS);
		local iteration = 0;
		local word = 0x0;
		_i2c.write(_addr, SA_CHARGER_STATUS);
		do {
		  // imp.sleep(0.1);
		  // imp.wakeup(0.05)
		  word = _i2c.read(_addr, SA_CHARGER_STATUS, 1);
		  // server.log(word);
		  iteration += 1;
		  if (iteration > POLL_ITERATION_MAX) {
		    server.log("Polled 100 times and gave up.");
		    break;
		  }
		} while (word == null);
		server.log(word);
		// _i2c.readerror();
		// Wait for the sensor to finish the reading
		// ERROR: the index '0' does not exist
		// while ((_i2c.read(_addr, SA_CHARGER_STATUS + "", 1)[0] & 0x80) == 0x80) {
		// 	log(_i2c.read(_addr, SA_CHARGER_STATUS + "", 1));
		// }
		// timeout
	}
}

// Configure i2c bus
// This method configures the I²C clock speed and enables the port.
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

// LTC4156 battery charger 0x12 
server.log(hardware.i2c89.write(0x12, "\x03"));
server.log(hardware.i2c89.read(0x12, "\x03", 1)[0]);
server.log(hardware.i2c89.write(0x12, "\x02"));
server.log(hardware.i2c89.read(0x12, "\x02", 1)[0]);

// HTU21D ambient humidity sensor 0x80
// server.log(hardware.i2c89.write(0x80, ""));

// VREF is VSYS – voltage=2.8V 
// PIN 7 – ADC_AUX – measurement solar cell voltage (divided by/3, limited to zener 
// voltage 6V) 
// PIN A- ADC_S – soil moisture sensor (up to Vsys) 
// PIN B – ADC_B - LTC4156 system voltage (divided by/2, charger voltage or battery 
// voltage) 


// Create PowerManager object
powerManager <- PowerManager(hardware.i2c89);
// powerManager.sample();

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
				log("Note that subsequent 'sensing' wakes won't log here.");
				log("The next wake to log will be the 'data transmission' wake.");
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

// return true iff the collected data should be sent to the server
function is_server_refresh_needed(data_last_sent, data_current) {
	// first boot, always send
	if (data_last_sent == null)     return true;

	local send_interval_s = 0;

	send_interval_s = 60*1;

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
		log("Connected to server.");
		agent.send("data", { device = hardware.getimpeeid(), data = nv.data} ); // TODO: send error codes
		local success = server.flush(TIMEOUT_SERVER_S);
		if (success) {
			// update last sent data (even on failure, so the next send attempt is not immediate)
			nv.data_sent = nv.data.top();
			
			// clear non-volatile storage
			nv.data.clear();
		} else {
			log("Error: Server connected, but no success.");
		}
	} else {
		log("Error: Server is not connected.");
	}
	
	// Sleep until next sensor sampling
	power.enter_deep_sleep_running("Finished sending JSON data.");
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
	// I could remove this, since, according to Hugo:
	// When you wake from an imp.deepsleep or server.sleep,
	// wifi is not up - there's no need to immediately disconnect.
	// You'd have to either explicitly connect (if you are using
	// RETURN_ON_ERROR) or perform an operation which requires
	// network (if you're using SUSPEND_ON_ERROR).
	// server.disconnect();
	server.disconnect();
	
	// Useless according to Hugo from Electric Imp
	// imp.setpowersave(true);
	imp.enableblinkup(false);
	
	// create non-volatile storage if it doesn't exist
	if (!("nv" in getroottable() && "data" in nv)) {
		nv <- { data = [], data_sent = null, running_state = true };
	}
	
	// we have entered the running state
	nv.running_state = true;

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
		ts = time()
	});

	//Send sensor data
	if (is_server_refresh_needed(nv.data_sent, nv.data.top())) {
		if (server.isconnected()) {
			log("Server refresh needed and server connected");
			// already connected (first boot?). send data.
			send_data(SERVER_CONNECTED);
		} else {
			log("Server refresh needed but need to connect first");
			// connect first then send data.
			server.connect(send_data, TIMEOUT_SERVER_S);
		}
	} else {
		// not time to send. sleep until next sensor sampling.
		log("Not time to send");
		power.enter_deep_sleep_running("Not time yet");
	}
	
}

agent.on("location_request", function(data) {
	log("Agent requested location information.");
	send_loc();
});

main();
