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
// Power controller
////////////////////////
class powerController {
	// Pin 9 is SDA
	// Pin 8 is SCL

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
