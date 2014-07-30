////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
//
// Imp Agent code runs on a server in the Imp Cloud. 
// It forwards data from the Imp Device to the Edyn server.
////////////////////////////////////////////////////////////

// Send data to Edyn server
function send_data_json(data) {
    // local soil_url = "https://edyn.com/api/v1/readings?" + "impee_id=" + data.device;
    // local soil_url = "http://edynbackendpythonstag.elasticbeanstalk.com/api/readings/?" + "impee_id=" + data.device;
    local soil_url = "http://edynbackendpythonstag.elasticbeanstalk.com/api/readings/";
    local req = http.post(soil_url, {"Content-Type":"application/json", "User-Agent":"Imp"}, http.jsonencode(data));
    local res = req.sendsync();
    if (res.statuscode != 200) {
        // TODO: retry?
        // server.log("error sending message: " + res.body);
        server.log("error sending message: " + "Error too long to log");
    }
}

// Convert data to Edyn format and send to Edyn server
function send_data(data) {
    // Convert data to Edyn format
    local body = "impee_id=" + data.device + "&data_string=";
    foreach(val in data.data) {
        body += format("L%.2fLM%.2fMT%.2fTH%.2fH", val.l, val.m, val.t, val.h);
    }
    server.log(body);

    // Send to Edyn server
    // local soil_url = "https://edyn.com/api/v1/readings?" + body;
    local soil_url = "http://edynbackendpythonstag.elasticbeanstalk.com/api/readings/?" + body;
    local req = http.post(soil_url, {"Content-Type":"text/csv", "User-Agent":"Imp"}, body);
    local res = req.sendsync();
    if (res.statuscode != 200) {
        // TODO: retry?
        server.log("error sending message: " + res.body);
    }
}

// Invoked when the device calls agent.send("data", ...)
device.on("data", function(data) {
    // data[sd] <- [1, 2];
    local dataToSend = data;
    // temp code to work with back end expectation of sd key
    // dataToSend.data[0].sd <- [];
    
    dataToSend.lat <- 37.8049851;
    dataToSend.lng <- -122.2696578;
    
    //data_buffer.extend(data.data); // for debug
    server.log(http.jsonencode(dataToSend));
    //send_data(data); // legacy API
    send_data_json(dataToSend); // JSON API
});

// Invoked when the device calls agent.send("location", ...)
device.on("location", function(data) {
  server.log("Received location information");
    local url = "https://maps.googleapis.com/maps/api/browserlocation/json?browser=electric-imp&sensor=false";
    
    foreach (network in data.loc) {
        url += ("&wifi=mac:" + addColons(network.bssid) + "|ss:" + network.rssi);
    }
    server.log(url);

    // If this is the first time we've received location data
    
    // local request = http.get(url);
    // local response = request.sendsync();

    // if (response.statuscode == 200) {
    //     // server.log(response.body);
    //     local googleData = response.body;
    //     server.log(googleData);
    //     server.log(googleData["location"]);
    //     lat = googleData["location"].lat;
    //     lng = googleData["location"].lng;

    //     server.log("http://maps.google.com/maps?q=loc:" + googleData["location"].lat + "," + googleData["location"].lng);
    // }
    
    // Else use old value
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

function addColons(bssid) {
    local result = bssid.slice(0, 2);
    
    for (local i = 2; i < 12; i += 2) {
        result += ":" + bssid.slice(i, (i + 2));
    }
    
    return result;
}

function main() {
  // Any new blinkup will create a new agent, and hence the agent storage
  // (accessed with server.load/save) will be empty.
  // When the agent starts it can check to see if this is empty and
  // if so, send a message to the device.
  device.send("location_request",{});
  server.log("Initiated location information request");
}

device.onconnect(function() {
  // Any new blinkup will create a new agent, and hence the agent storage
  // (accessed with server.load/save) will be empty.
  // When the agent starts it can check to see if this is empty and
  // if so, send a message to the device.
  device.send("location_request",{});
  server.log("Initiated location information request");
});

main();