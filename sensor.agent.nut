////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
//
// Imp Agent code runs on a server in the Imp Cloud. 
// It forwards data from the Imp Device to the Edyn server.
////////////////////////////////////////////////////////////

// Send data to Edyn server
function send_data_json(data) {
  // local soil_url = "https://edyn.com/api/v1/readings?" + "impee_id=" + data.device;
//  local soil_url = "http://edynbackendpythonstag.elasticbeanstalk.com/api/readings/";
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
  
  local sap_url = "https://techedbc2228f55.us1.hana.ondemand.com/teched/SaveReading.htm";
  // local soil_url = "http://Soil-IQ-stag-zhipffkaue.elasticbeanstalk.com/api/readings/";
  req = http.post(sap_url, {"Content-Type":"application/json", "User-Agent":"Edyn"}, http.jsonencode(data));
  res = req.sendsync();
  if (res.statuscode != 200) {
    // TODO: retry?
    // server.log("error sending message: " + res.body);
    server.log("status code: " + res.statuscode);
    // server.log("error sending message: " + res.body.slice(0,40));
    server.log("Error sending message to SAP.");
  } else {
    server.log("Data sent successfully to SAP.");
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
    // Default values are the Oakland office
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
  send_data_json(dataToSend); // JSON API
});

// Invoked when the device calls agent.send("location", ...)
device.on("location", function(data) {

  server.log("Received location information");
  server.log(http.jsonencode(data));
  // Load the settings table in from permanent storage
  local settings = server.load();
  server.log(http.jsonencode(settings));
  
  // If we have some settings saved
  if (settings.len() == 4) {
    server.log("New SSID is " + data.ssid);
    server.log("Old SSID is " + settings.ssid);
    
    // If this is a new SSID
    if (settings.ssid != data.ssid) {
      local url = "https://maps.googleapis.com/maps/api/browserlocation/json?browser=electric-imp&sensor=false";
  
      foreach (network in data.loc) {
        url += ("&wifi=mac:" + addColons(network.bssid) + "|ss:" + network.rssi);
      }
      server.log(url);
  
      locPrefs <- {};
      locPrefs.ssid <- data.ssid;
      locPrefs.device <- data.device;

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
    }
    
    else {
      // If we were already using this SSID
      server.log("We already know the lat and lng for this device: lat,lng = " + settings.lat + "," + settings.lng);
    }
  }

  // If we don't have some settings saved
  // Assume this is a new SSID
  else {
    server.log("No existing SSID saved on the agent.");
    local url = "https://maps.googleapis.com/maps/api/browserlocation/json?browser=electric-imp&sensor=false";
  
    foreach (network in data.loc) {
      url += ("&wifi=mac:" + addColons(network.bssid) + "|ss:" + network.rssi);
    }
    server.log(url);
  
    locPrefs <- {};
    locPrefs.ssid <- data.ssid;
    locPrefs.device <- data.device;

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
  if (settings.len() == 4) {
    // Settings table has all the values we expected,
    // so set the locPrefs to the loaded table
    server.log("Device connected - We already know the lat and lng for this device: lat,lng = " + settings.lat + "," + settings.lng);
  }
  
  else {
    // Settings table doesn't have all the values we expected,
    // so figure out the locPrefs and save as a table
    device.send("location_request", {test = "t"});
    server.log("Initiated location information request");
  }
});

device.send("location_request", {test = "t"});
server.log("Initiated location information request");

// // Debug code used to allow data monitoring via JSON API
// data_buffer <- [];
// http.onrequest(function (request, response) {
//  try {
//    response.header("Access-Control-Allow-Origin", "*");
//    response.send(200, http.jsonencode(data_buffer));
//    data_buffer.clear();
//  } catch (ex) {
//    response.send(500, "Internal Server Error: " + ex);
//  }
// });

// Basic wrapper to create an execute an HTTP POST
function httpPostWrapper (url, headers, string) {
  local request = http.post(url, headers, string);
  local response = request.sendsync();
  return response;
}

// create a request handler
http.onrequest(function(request, response){
  // parse the url form encoded data into a table
//   local data = http.urldecode(request.body);
//   server.log(data);
  
//   foreach (point in data) {
//    server.log(point);
//  }
  local settings = server.load();
  // check if particular keys are in the parsed table
  if ("uid" in request.query && "action" in request.query) {
    server.log("uid " + request.query.uid);
    server.log("action " + request.query.action);
    if (request.query.action == "pair") {
      server.log("should pair");
      //http://edynbackendnodedev.elasticbeanstalk.com/users/:id/devices
      //https://api.edyn.com/users/:id/devices
      // local url = "http://edynbackendnodedev.elasticbeanstalk.com/users/";
      local url = "http://edynbackendnodedev.elasticbeanstalk.com/users/" + request.query.uid + "/devices";
      local headers = {}
      headers["X-Api-Key"] <- "FEIMfjweiovm90283y3#*U)#@URvm"
      headers["Content-Type"] <- "application/json"
      local stringToSend = "";
      server.log(settings.len())
      // if we have all the settings we should expect from the device
      if (settings.len() == 4) {
        server.log("Loading real device uuid");
        stringToSend = "{\"uuid\": \"" + settings.device + "\"}";
        server.log(url);
        server.log(headers["X-Api-Key"]);
        server.log(headers["Content-Type"]);
        server.log(stringToSend);
        httpPostWrapper(url,headers,stringToSend);
      }
      else {
        server.log("No uuid saved from device");
        // stringToSend = "{\"uuid\": " + "\"20000c2a690226d1\"" + "}";
        server.log("Error");
      }
      
    }
  }
    
  // send response to whoever hit the agent url
  if (settings.len() == 4) {
    response.send(200, settings.device);
  } else {
    response.send(500, "Error");
  }
});
