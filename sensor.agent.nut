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
        server.log("error sending message: " + res.body);
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
    dataToSend.data[0].sd <- [1, 2];
    //data_buffer.extend(data.data); // for debug
    server.log(http.jsonencode(dataToSend));
    //send_data(data); // legacy API
    send_data_json(dataToSend); // JSON API
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
