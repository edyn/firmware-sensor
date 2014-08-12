////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
//
// Imp Agent code runs on a server in the Imp Cloud. 
// It forwards data from the Imp Device to the Edyn server.
////////////////////////////////////////////////////////////

// Send data to Edyn server
function send_data_json(data) {
	// local soil_url = "https://edyn.com/api/v1/readings?" + "impee_id=" + data.device;
	// local soil_url = "http://edynbackendpythonstag.elasticbeanstalk.com/api/readings/";
	local soil_url = "http://edynbackendpythondev.elasticbeanstalk.com/api/readings/";
	// local soil_url = "http://Soil-IQ-stag-zhipffkaue.elasticbeanstalk.com/api/readings/";
	local req = http.post(soil_url, {"Content-Type":"application/json", "User-Agent":"Imp"}, http.jsonencode(data));
	local res = req.sendsync();
	if (res.statuscode != 200) {
		// TODO: retry?
		// server.log("error sending message: " + res.body);
		server.log("status code: " + res.statuscode);
		// server.log("error sending message: " + res.body.slice(0,40));
		server.log("Error sending message to database.");
	} else {
		server.log("Data sent successfully to database.");
	}
}

// Invoked when the device calls agent.send("data", ...)
device.on("data", function(data) {
	// data[sd] <- [1, 2];
	local dataToSend = data;
	// temp code to work with back end expectation of sd key
	// dataToSend.data[0].sd <- [];
	
	local settings = server.load();
	// If no preferences have been saved, settings will be empty
	if (settings.len() != 0) {
		// Settings table is NOT empty so set the
		// lat and lng to the values from the loaded table
		dataToSend.lat <- settings.lat;
		dataToSend.lng <- settings.lng;
	} else {
		// Settings table IS empty
		// Default values
		dataToSend.lat <- 37.362517;
		dataToSend.lng <- -122.03476;
	}
	
	// Hacks
	foreach (point in dataToSend.data) {
		point.sd <- [1];
	}
	
	//data_buffer.extend(data.data); // for debug
	server.log(http.jsonencode(dataToSend));
	
	// Commented out while hacking on the new power controller
	// send_data_json(dataToSend); // JSON API
});

// Invoked when the device calls agent.send("location", ...)
device.on("location", function(data) {
	server.log("Received location information");
	local url = "https://maps.googleapis.com/maps/api/browserlocation/json?browser=electric-imp&sensor=false";
	
	foreach (network in data.loc) {
		url += ("&wifi=mac:" + addColons(network.bssid) + "|ss:" + network.rssi);
	}
	server.log(url);
	
	locPrefs <- {};

	// If this is the first time we've received location data
	
	local request = http.get(url);
	local response = request.sendsync();

	if (response.statuscode == 200) {
		// server.log(response.body);
		local googleData = http.jsondecode(response.body);
		// server.log(googleData);
		server.log(googleData["location"].lat);
		server.log(googleData["location"].lng);
		
		locPrefs.lat <- googleData["location"].lat;
		locPrefs.lng <- googleData["location"].lng;
		server.save(locPrefs);
	}
	
});

function addColons(bssid) {
	local result = bssid.slice(0, 2);
	
	for (local i = 2; i < 12; i += 2) {
		result += ":" + bssid.slice(i, (i + 2));
	}
	
	return result;
}


device.onconnect(function() {
	// Any new blinkup will create a new agent, and hence the agent storage
	// (accessed with server.load/save) will be empty.
	// When the agent starts it can check to see if this is empty and
	// if so, send a message to the device.
	
	// Load the settings table in from permanent storage
	local settings = server.load();
	// If no preferences have been saved, settings will be empty
	if (settings.len() != 0) {
	// Settings table is NOT empty so set the locPrefs to the loaded table
	server.log("We already know the lat and lng for this device: lat,lng = " + settings.lat + "," + settings.lng);
	} else {
	// Settings table IS empty so figure out the locPrefs and save as a table
	device.send("location_request", {test = "t"});
	server.log("Initiated location information request");
	}
});

// Debug code used to allow data monitoring via JSON API
data_buffer <- [];
http.onrequest(function (request, response) {
	try {
		response.header("Access-Control-Allow-Origin", "*");
		response.send(200, http.jsonencode(data_buffer));
		data_buffer.clear();
	} catch (ex) {
		response.send(500, "Internal Server Error: " + ex);
	}
});

