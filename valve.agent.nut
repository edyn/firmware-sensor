////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Valve
//
// Imp Agent code runs on a server in the Imp Cloud. 
// It accepts requests to open and close the valve and
// passes it to the Imp Device when the device requests.
// The Imp Device sends status data (valve state, battery
// voltage, etc) to the Edyn Server before the request.
// 
// Open requests must include a time and duration.
// Close requests must include a time.
//
// If time has already passed, the action will take place
// as soon as the Imp Device wakes and receives the request.
// The duration is set to two hours, if greater. Time and
// duration specified in seconds.
////////////////////////////////////////////////////////////

//this comment is a feature!

// Invoked when the device calls agent.send(...)
device.on("action_request", function(data) {
    // send the action to the device and clear it
    device.send("action_response", server.load());
    server.save({});
    
    // append agent url to data
    data.url <- http.agenturl();
    server.log(http.jsonencode(data));

    // send data to edyn server
    // local req = http.post(
    //     "https://edyn.com/api/v1/valve", 
    //     {"Content-Type":"text/csv", "User-Agent":"Imp"},
    //     http.jsonencode(data));
    local req = http.post(
        "http://edynbackendpythonstag.elasticbeanstalk.com/api/valve/", 
        {"Content-Type":"text/csv", "User-Agent":"Imp"},
        http.jsonencode(data));
    local res = req.sendsync();
    if (res.statuscode != 200) {
        // TODO: retry?
        server.log("error sending message: " + res.body);
    }
});

// Accept requests to open/close the valve
http.onrequest(function (request, response) {
    try {
        response.header("Access-Control-Allow-Origin", "*");

        if (request.query.action == "open") {
            server.save({action = request.query.action, time = request.query.time.tointeger(), duration = request.query.duration.tointeger()}); // seconds
            response.send(200, "OK");
        } else if (request.query.action == "close") {
            server.save({action = request.query.action, time = request.query.time.tointeger()});  // seconds
            response.send(200, "OK");
        } else {
            response.send(500, "Error: Action should be 'open' or 'close'.");
        }
    } catch (ex) {
        response.send(500, "Error: " + ex);
    }
});
