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
}

// Send data to the readings API
function send_data_json_node(data) {
  local readings_url = "http://edynapireadings.elasticbeanstalk.com/readings/";
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
  local dataToSendNode = {};
  dataToSendNode.data <- [];
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
  
  local newPoint = {};
  // Hacks
  foreach (point in dataToSend.data) {
    point.sd <- [1];
  }
  foreach (point in data.data) {
    newPoint.uuid <- "30000c2a69000001";
    newPoint.timestamp <- point.ts;
    newPoint.battery <- point.b;
    newPoint.humidity <- point.h;
    newPoint.temperature <- point.t;
    newPoint.electrical_conductivity <- point.m;
    newPoint.light <- point.l;

    // newPoint.disable_input_uvcl <- false;
    newPoint.disable_input_uvcl <- (point.REG0 & 0x80) != 0x00;

    local convertCurrentLim = function(input) {
      if (input == 0x00) return "100mA Max (USB Low Power)"
      if (input == 0x01) return "500mA Max (USB High Power)"
      if (input == 0x02) return "600mA Max"
      if (input == 0x03) return "700mA Max"
      if (input == 0x04) return "800mA Max"
      if (input == 0x05) return "900mA Max (USB 3.0)"
      if (input == 0x06) return "1000mA Typical"
      if (input == 0x07) return "1250mA Typical"
      if (input == 0x08) return "1500mA Typical"
      if (input == 0x09) return "1750mA Typical"
      if (input == 0x0A) return "2000mA Typical"
      if (input == 0x0B) return "2250mA Typical"
      if (input == 0x0C) return "2500mA Typical"
      if (input == 0x0D) return "2750mA Typical"
      if (input == 0x0E) return "3000mA Typical"
      if (input == 0x0F) return "2.5mA Max (USB Suspend)"
      if (input == 0x1F) return "SELECT CLPROG1"
    }

    // NEED TO THINK ABOUT MORE
    // newPoint.wall_i_lim <- 0;
    local wall_i_lim = (point.REG1 & 0x1f);
    newPoint.wall_i_lim <- convertCurrentLim(wall_i_lim);

    // In minutes, different than data sheet
    // newPoint.timer <- 60;
    local timer = (point.REG1 & 0x60) >> 5;
    if (timer == 0x0) newPoint.timer <- 60;
    if (timer == 0x1) newPoint.timer <- 240;
    if (timer == 0x2) newPoint.timer <- 15;
    if (timer == 0x3) newPoint.timer <- 30;
    
    // newPoint.i_charge <- 100.0;
    local i_charge = ((point.REG2 & 0xf0) >> 4).tofloat();
    newPoint.i_charge <- ((i_charge-1)*6.25)+12.5
    if (newPoint.i_charge < 12.49) newPoint.i_charge = 0.0;
    
    // newPoint.v_float <- 3.45;
    local v_float = (point.REG2 & 0xc) >> 2;
    if (v_float == 0x0) newPoint.v_float <- 3.45;
    if (v_float == 0x1) newPoint.v_float <- 3.55;
    if (v_float == 0x2) newPoint.v_float <- 3.60;
    if (v_float == 0x3) newPoint.v_float <- 3.80;
    
    // newPoint.c_x_set <- 10;
    local c_x_set = (point.REG2 & 0x3);
    if (c_x_set == 0x0) newPoint.c_x_set <- 10;
    if (c_x_set == 0x1) newPoint.c_x_set <- 20;
    if (c_x_set == 0x2) newPoint.c_x_set <- 2;
    if (c_x_set == 0x3) newPoint.c_x_set <- 5;
    
    // newPoint.charger_status <- "Charger Off";
    local charger_status = (point.REG3 & 0xe0) >> 5;
    if (charger_status == 0x0) newPoint.charger_status <- "Charger Off";
    if (charger_status == 0x1) newPoint.charger_status <- "Low Battery Voltage";
    if (charger_status == 0x2) newPoint.charger_status <- "Constant Current";
    if (charger_status == 0x3) newPoint.charger_status <- "Constant Voltage, VPROG>VC/X";
    if (charger_status == 0x4) newPoint.charger_status <- "Constant Voltage, VPROG<VC/X";
    if (charger_status == 0x6) newPoint.charger_status <- "NTC TOO COLD, Charging Paused";
    if (charger_status == 0x7) newPoint.charger_status <- "NTC HOT FAULT, Charging Paused";

    // newPoint.ntc_stat <- "NTC Normal";
    local ntc_stat = (point.REG3 & 0x6) >> 1;
    if (ntc_stat == 0x0) newPoint.ntc_stat <- "NTC Normal";
    if (ntc_stat == 0x1) newPoint.ntc_stat <- "NTC_TOO_COLD";
    if (ntc_stat == 0x3) newPoint.ntc_stat <- "NTC_HOT_FAULT";
    
    // newPoint.low_bat <- true;
    newPoint.low_bat <- (point.REG3 & 0x1) != 0x00;
    
    // newPoint.ext_pwr_good <- true;
    newPoint.ext_pwr_good <- (point.REG4 & 0x80) != 0x00;
    
    // newPoint.wall_sns_good <- true;
    newPoint.wall_sns_good <- (point.REG4 & 0x20) != 0x00;
    
    // newPoint.at_input_ilim <- false;
    newPoint.at_input_ilim <- (point.REG4 & 0x10) != 0x00;
    
    // newPoint.input_uvcl_active <- false;
    newPoint.input_uvcl_active <- (point.REG4 & 0x8) != 0x00;
    
    // newPoint.ovp_active <- false;
    newPoint.ovp_active <- (point.REG4 & 0x4) != 0x00;
    
    // newPoint.bad_cell <- false;
    newPoint.bad_cell <- (point.REG4 & 0x1) != 0x00;
    
    // SWITCHED THIS TO INTEGER!
    // newPoint.ntc_val <- 20.0;
    newPoint.ntc_val <- ((point.REG5 & 0xfe) >> 1).tointeger();
    
    // newPoint.ntc_warning <- false;
    newPoint.ntc_warning <- (point.REG5 & 0x1) != 0x00;

    dataToSendNode.data.append(newPoint);
  }
  
  //data_buffer.extend(data.data); // for debug
  server.log(http.jsonencode(dataToSend));
  server.log("Number of sensor measurements and power manager statuses is " + dataToSendNode.data[0].len());
  
  // Core
  server.log("timestamp " + dataToSendNode.data[0].timestamp + ", battery " + dataToSendNode.data[0].battery);
  server.log("temperature " + dataToSendNode.data[0].temperature + ", humidity " + dataToSendNode.data[0].humidity);
  server.log("light " + dataToSendNode.data[0].light + ", electrical_conductivity " + dataToSendNode.data[0].electrical_conductivity);
  
  // Text
  server.log("charger_status " + dataToSendNode.data[0].charger_status);
  server.log("ntc_stat " + dataToSendNode.data[0].ntc_stat);
  server.log("wall_i_lim " + dataToSendNode.data[0].wall_i_lim);
  
  // Numbers
  server.log("i_charge " + dataToSendNode.data[0].i_charge);
  server.log("ntc_val " + dataToSendNode.data[0].ntc_val + ", timer " + dataToSendNode.data[0].timer);
  server.log("v_float " + dataToSendNode.data[0].v_float + ", c_x_set " + dataToSendNode.data[0].c_x_set);
  
  // Booleans
  server.log("ext_pwr_good " + dataToSendNode.data[0].ext_pwr_good + ", wall_sns_good " + dataToSendNode.data[0].wall_sns_good);
  // Low cell voltage is only meaningful when input (WALL or USB) power is available
  // and the battery charger is enabled,
  // or when automatic or manual enable of the step-up regulator has been requested.
  server.log("low_bat (with caveats) " + dataToSendNode.data[0].low_bat + ", bad_cell " + dataToSendNode.data[0].bad_cell);
  server.log("at_input_ilim " + dataToSendNode.data[0].at_input_ilim + ", ovp_active " + dataToSendNode.data[0].ovp_active);
  server.log("input_uvcl_active " + dataToSendNode.data[0].input_uvcl_active + ", disable_input_uvcl " + dataToSendNode.data[0].disable_input_uvcl);
  server.log("ntc_warning " + dataToSendNode.data[0].ntc_warning);
  
  // Commented out while hacking on the new power controller
  send_data_json(dataToSend); // JSON API
  // send_data_json_node(dataToSendNode);
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

// device.send("location_request", {test = "t"});
// server.log("Initiated location information request");

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

// Basic wrapper to create and execute an HTTP POST
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
