////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
//
// Imp Agent code runs on a server in the Imp Cloud. 
// It forwards data from the Imp Device to the Edyn server.
////////////////////////////////////////////////////////////
GlobalTest <- 1
fullResSet <- false
THEMACADDRESSAGENTSIDE<-"unknownMacAddress"

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
    server.log("MySQL API status code: " + res.statuscode);
    // server.log("error sending message: " + res.body.slice(0,40));
    server.log("Error sending message to MySQL database.");
  } 
  else {
    server.log("Data sent successfully to MySQL database.");
  }
}



// Send data to the readings API
function send_data_json_node(data) {
  server.log(http.jsonencode(data));
  local readings_url = "https://readings.edyn.com/readings/";
  local req = http.post(readings_url, {"Content-Type":"application/json", "User-Agent":"Imp", "X-Api-Key":"FEIMfjweiovm90283y3#*U)#@URvm"}, http.jsonencode(data));
  local res = req.sendsync();
  if (res.statuscode != 200) {
    // TODO: retry?
    // server.log("error sending message: " + res.body);
    server.log("Postgres API status code: " + res.statuscode);
    server.log(res.body);
    // server.log("error sending message: " + res.body.slice(0,40));
    server.log("Error sending message to Postgres database.");
  } 
  else {
    server.log("Data sent successfully to Postgres database.");
  }
}


function processResponse(incomingDataTable) {
  // This is the completed-request callback function.
  if (incomingDataTable.statuscode != 200) {
    // TODO: retry?
    // server.log("error sending message: " + res.body);
    server.log("API status code: " + res.statuscode);
    // server.log(res.body);
    // server.log("error sending message: " + res.body.slice(0,40));
    server.log("Error saving device location in DB.");
  }
  else {
    server.log("Device location saved in DB successfully.");
  }
}

// Send location of device
function send_loc_data(data) {
  server.log(http.jsonencode(data));
  local message = http.jsonencode(data);
  local readings_url = "https://api.edyn.com/devicelocation/";
  local req = http.post(readings_url, {"Content-Type":"application/json", "User-Agent":"Imp", "X-Api-Key":"FEIMfjweiovm90283y3#*U)#@URvm"}, message);
  req.sendasync(processResponse);
}

// Invoked when the device calls agent.send("data", ...)
device.on("data", function(data) {
  // data[sd] <- [1, 2];
  if(!("power_data" in data)) {//WITHOUT powerdata
    // data[sd] <- [1, 2];
    local dataToSend = data;
    local dataToSendNode = {};
    dataToSendNode.uuid <- data.device;
    THEMACADDRESSAGENTSIDE=data.device;
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
    } 
    else {
      // Settings table IS empty
      // Default values are the Oakland office
      dataToSend.lat <- 37.362517;
      dataToSend.lng <- -122.03476;
    }
    
    local newPoint = {};
    // Hacks
    foreach (origPoint in dataToSend.data) {
      origPoint.sd <- [1];
    }
    
    //commented out 17/6/15
    //send_data_json(dataToSend); // JSON API
    
    foreach (point in data.data) {
      newPoint = {};
      newPoint.timestamp <- point.ts;
      newPoint.battery <- point.b;
      newPoint.humidity <- point.h;
      newPoint.temperature <- point.t;
      newPoint.electrical_conductivity <- point.m;
      newPoint.light <- point.l;
      newPoint.capacitance<-point.c;
    
      server.log("Agent CAPACITANCE:")
      server.log(point.c)
      server.log(newPoint.capacitance)
    
      // newPoint.disable_input_uvcl <- false;
      newPoint.disable_input_uvcl <- (point.r0 & 0x80) != 0x00;

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
    local wall_i_lim = (point.r1 & 0x1f);
    newPoint.wall_i_lim <- convertCurrentLim(wall_i_lim);

    // In minutes, different than data sheet
    // newPoint.timer <- 60;
    local timer = (point.r1 & 0x60) >> 5;
    if (timer == 0x0) newPoint.timer <- 60;
    if (timer == 0x1) newPoint.timer <- 240;
    if (timer == 0x2) newPoint.timer <- 15;
    if (timer == 0x3) newPoint.timer <- 30;
    
    // newPoint.i_charge <- 100.0;
    local i_charge = ((point.r2 & 0xf0) >> 4).tofloat();
    newPoint.i_charge <- ((i_charge-1)*6.25)+12.5
    if (newPoint.i_charge < 12.49) newPoint.i_charge = 0.0;
    
    // newPoint.v_float <- 3.45;
    local v_float = (point.r2 & 0xc) >> 2;
    if (v_float == 0x0) newPoint.v_float <- 3.45;
    if (v_float == 0x1) newPoint.v_float <- 3.55;
    if (v_float == 0x2) newPoint.v_float <- 3.60;
    if (v_float == 0x3) newPoint.v_float <- 3.80;
    
    // newPoint.c_x_set <- 10;
    local c_x_set = (point.r2 & 0x3);
    if (c_x_set == 0x0) newPoint.c_x_set <- 10;
    if (c_x_set == 0x1) newPoint.c_x_set <- 20;
    if (c_x_set == 0x2) newPoint.c_x_set <- 2;
    if (c_x_set == 0x3) newPoint.c_x_set <- 5;
    
    // newPoint.charger_status <- "Charger Off";
    local charger_status = (point.r3 & 0xe0) >> 5;
    if (charger_status == 0x0) newPoint.charger_status <- "Charger Off";
    if (charger_status == 0x1) newPoint.charger_status <- "Low Battery Voltage";
    if (charger_status == 0x2) newPoint.charger_status <- "Constant Current";
    if (charger_status == 0x3) newPoint.charger_status <- "Constant Voltage, VPROG>VC/X";
    if (charger_status == 0x4) newPoint.charger_status <- "Constant Voltage, VPROG<VC/X";
    if (charger_status == 0x6) newPoint.charger_status <- "NTC TOO COLD, Charging Paused";
    if (charger_status == 0x7) newPoint.charger_status <- "NTC HOT FAULT, Charging Paused";

    // newPoint.ntc_stat <- "NTC Normal";
    local ntc_stat = (point.r3 & 0x6) >> 1;
    if (ntc_stat == 0x0) newPoint.ntc_stat <- "NTC Normal";
    else if (ntc_stat == 0x1) newPoint.ntc_stat <- "NTC_TOO_COLD";
    else if (ntc_stat == 0x3) newPoint.ntc_stat <- "NTC_HOT_FAULT";
    else {
      server.log("NTC STAT IS:");
      server.log(ntc_stat);
      newPoint.ntc_stat <- "NTC BUGGED OUT";
    }
    
    server.log("NTC STAT IS:")
    server.log(ntc_stat)
    // newPoint.low_bat <- true;
    newPoint.low_bat <- (point.r3 & 0x1) != 0x00;
    
    // newPoint.ext_pwr_good <- true;
    newPoint.ext_pwr_good <- (point.r4 & 0x80) != 0x00;
    
    // newPoint.wall_sns_good <- true;
    newPoint.wall_sns_good <- (point.r4 & 0x20) != 0x00;
    
    // newPoint.at_input_ilim <- false;
    newPoint.at_input_ilim <- (point.r4 & 0x10) != 0x00;
    
    // newPoint.input_uvcl_active <- false;
    newPoint.input_uvcl_active <- (point.r4 & 0x8) != 0x00;
    
    // newPoint.ovp_active <- false;
    newPoint.ovp_active <- (point.r4 & 0x4) != 0x00;
    
    // newPoint.bad_cell <- false;
    newPoint.bad_cell <- (point.r4 & 0x1) != 0x00;
    
    // SWITCHED THIS TO INTEGER!
    // newPoint.ntc_val <- 20.0;
    newPoint.ntc_val <- ((point.r5 & 0xfe) >> 1).tointeger();
    
    // newPoint.ntc_warning <- false;
    newPoint.ntc_warning <- (point.r5 & 0x1) != 0x00;

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
    send_data_json_node(dataToSendNode);
  } 
  else {//WITH powerdata
    local dataToSend = data;
    local dataToSendNode = {};
    dataToSendNode.uuid <- data.device;
    dataToSendNode.data <- [];
    dataToSendNode.powerData<-{};
    // temp code to work with back end expectation of sd key
    // dataToSend.data[0].sd <- [];
    
    local settings = server.load();
    // If no preferences have been saved, settings will be empty
    if (settings.len() != 0) {
      // Settings table is NOT empty so set the
      // lat and lng to the values from the loaded table
      dataToSend.lat <- settings.lat;
      dataToSend.lng <- settings.lng;
    }
    else {
      // Settings table IS empty
      // Default values are the Oakland office
      dataToSend.lat <- 37.362517;
      dataToSend.lng <- -122.03476;
    }
    
    local newPoint = {};
    // Hacks
    foreach (origPoint in dataToSend.data) {
      origPoint.sd <- [1];
    }
    
    //commented out 17/6/15
    //send_data_json(dataToSend); // JSON API
    
    
    //Seperated powermanager register data from data.data
    //added testResults handling for unit tests (checks for them first)
    foreach (point in data.data) {
      newPoint = {};
      newPoint.timestamp <- point.ts;
      newPoint.battery <- point.b;
      newPoint.humidity <- point.h;
      newPoint.temperature <- point.t;
      newPoint.electrical_conductivity <- point.m;
      newPoint.light <- point.l;
      newPoint.capacitance <- point.c;
    
      if("testResults" in point){
        if(typeof(point.testResults)=="array"){
          for(local i=0; i<point.testResults.len(); i++){
            server.log("Test Results " + i + " = " +point.testResults[i])
          }
        }
        else /*if(typeof(point.testResults)=="string")*/{
          server.log(point.testResults)
        }
        //server.log("TestResults:"+typeof(point.testResults))
      }
      //dataToSendNode.data.append(newPoint);
      dataToSendNode.data.append(newPoint);
    }
    
    //Table of power information passed to agent
    local powerPoint={};
    
    powerPoint.disable_input_uvcl <- (data.power_data[0] & 0x80) != 0x00;
    
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
    local wall_i_lim = (data.power_data[1] & 0x1f);
    powerPoint.wall_i_lim <- convertCurrentLim(wall_i_lim);

    // In minutes, different than data sheet
    // newPoint.timer <- 60;
    local timer = (data.power_data[1] & 0x60) >> 5;
    if (timer == 0x0) powerPoint.timer <- 60;
    if (timer == 0x1) powerPoint.timer <- 240;
    if (timer == 0x2) powerPoint.timer <- 15;
    if (timer == 0x3) powerPoint.timer <- 30;
    
    // newPoint.i_charge <- 100.0;
    local i_charge = ((data.power_data[2] & 0xf0) >> 4).tofloat();
    powerPoint.i_charge <- ((i_charge-1)*6.25)+12.5
    if (powerPoint.i_charge < 12.49) powerPoint.i_charge = 0.0;
    
    // newPoint.v_float <- 3.45;
    local v_float = (data.power_data[2] & 0xc) >> 2;
    if (v_float == 0x0) powerPoint.v_float <- 3.45;
    if (v_float == 0x1) powerPoint.v_float <- 3.55;
    if (v_float == 0x2) powerPoint.v_float <- 3.60;
    if (v_float == 0x3) powerPoint.v_float <- 3.80;
    
    // newPoint.c_x_set <- 10;
    local c_x_set = (data.power_data[2] & 0x3);
    if (c_x_set == 0x0) powerPoint.c_x_set <- 10;
    if (c_x_set == 0x1) powerPoint.c_x_set <- 20;
    if (c_x_set == 0x2) powerPoint.c_x_set <- 2;
    if (c_x_set == 0x3) powerPoint.c_x_set <- 5;
    
    // newPoint.charger_status <- "Charger Off";
    local charger_status = (data.power_data[3] & 0xe0) >> 5;
    if (charger_status == 0x0) powerPoint.charger_status <- "Charger Off";
    if (charger_status == 0x1) powerPoint.charger_status <- "Low Battery Voltage";
    if (charger_status == 0x2) powerPoint.charger_status <- "Constant Current";
    if (charger_status == 0x3) powerPoint.charger_status <- "Constant Voltage, VPROG>VC/X";
    if (charger_status == 0x4) powerPoint.charger_status <- "Constant Voltage, VPROG<VC/X";
    if (charger_status == 0x6) powerPoint.charger_status <- "NTC TOO COLD, Charging Paused";
    if (charger_status == 0x7) powerPoint.charger_status <- "NTC HOT FAULT, Charging Paused";

    // newPoint.ntc_stat <- "NTC Normal";
    local ntc_stat = (data.power_data[3] & 0x6) >> 1;
    if (ntc_stat == 0x0) powerPoint.ntc_stat <- "NTC Normal";
    else if (ntc_stat == 0x1) powerPoint.ntc_stat <- "NTC_TOO_COLD";
    else if (ntc_stat == 0x3) powerPoint.ntc_stat <- "NTC_HOT_FAULT";
    else {
      server.log("NTC STAT IS:")
      server.log(ntc_stat)
      powerPoint.ntc_stat <- "NTC BUGGED OUT"
    }
    
    server.log("NTC STAT IS:")
    server.log(ntc_stat)
    
    // newPoint.low_bat <- true;
    powerPoint.low_bat <- (data.power_data[3] & 0x1) != 0x00;
    
    // newPoint.ext_pwr_good <- true;
    powerPoint.ext_pwr_good <- (data.power_data[4] & 0x80) != 0x00;
    
    // newPoint.wall_sns_good <- true;
    powerPoint.wall_sns_good <- (data.power_data[4] & 0x20) != 0x00;
    
    // newPoint.at_input_ilim <- false;
    powerPoint.at_input_ilim <- (data.power_data[4] & 0x10) != 0x00;
    
    // newPoint.input_uvcl_active <- false;
    powerPoint.input_uvcl_active <- (data.power_data[4] & 0x8) != 0x00;
    
    // newPoint.ovp_active <- false;
    powerPoint.ovp_active <- (data.power_data[4] & 0x4) != 0x00;
    
    // newPoint.bad_cell <- false;
    powerPoint.bad_cell <- (data.power_data[4] & 0x1) != 0x00;
    
    // SWITCHED THIS TO INTEGER!
    // newPoint.ntc_val <- 20.0;
    powerPoint.ntc_val <- ((data.power_data[5] & 0xfe) >> 1).tointeger();
    
    // newPoint.ntc_warning <- false;
    powerPoint.ntc_warning <- (data.power_data[5] & 0x1) != 0x00;
    
    //append to dataToSendNode
    
    dataToSendNode.powerData=powerPoint;

    //data_buffer.extend(data.data); // for debug
    server.log(http.jsonencode(dataToSend));
    server.log("Number of sensor measurements and power manager statuses is " + dataToSendNode.data[0].len());
    
    // Core
    server.log("timestamp " + dataToSendNode.data[0].timestamp + ", battery " + dataToSendNode.data[0].battery);
    server.log("temperature " + dataToSendNode.data[0].temperature + ", humidity " + dataToSendNode.data[0].humidity);
    server.log("light " + dataToSendNode.data[0].light + ", electrical_conductivity " + dataToSendNode.data[0].electrical_conductivity);
    
    // Text
    server.log("charger_status " + dataToSendNode.powerData.charger_status);
    server.log("ntc_stat " + dataToSendNode.powerData.ntc_stat);
    server.log("wall_i_lim " + dataToSendNode.powerData.wall_i_lim);
    
    // Numbers
    server.log("i_charge " + dataToSendNode.powerData.i_charge);
    server.log("ntc_val " + dataToSendNode.powerData.ntc_val + ", timer " + dataToSendNode.powerData.timer);
    server.log("v_float " + dataToSendNode.powerData.v_float + ", c_x_set " + dataToSendNode.powerData.c_x_set);
    
    // Booleans
    server.log("ext_pwr_good " + dataToSendNode.powerData.ext_pwr_good + ", wall_sns_good " + dataToSendNode.powerData.wall_sns_good);
    // Low cell voltage is only meaningful when input (WALL or USB) power is available
    // and the battery charger is enabled,
    // or when automatic or manual enable of the step-up regulator has been requested.
    server.log("low_bat (with caveats) " + dataToSendNode.powerData.low_bat + ", bad_cell " + dataToSendNode.powerData.bad_cell);
    server.log("at_input_ilim " + dataToSendNode.powerData.at_input_ilim + ", ovp_active " + dataToSendNode.powerData.ovp_active);
    server.log("input_uvcl_active " + dataToSendNode.powerData.input_uvcl_active + ", disable_input_uvcl " + dataToSendNode.powerData.disable_input_uvcl);
    server.log("ntc_warning " + dataToSendNode.powerData.ntc_warning);
    // Commented out while hacking on the new power controller
    send_data_json_node(dataToSendNode);
  }
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
        // local dataToSendApi = {};
        send_loc_data(locPrefs);
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
      send_loc_data(locPrefs);
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
  
  
  if(fullResSet){
    server.log("here");
    device.send("fullRes", {data="1"});
    server.log("Full Res Set request sent");
    server.log("Full Res Set To False");
    fullResSet=false;
  }
  
  
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
      local url = "https://api.edyn.com/users/" + request.query.uid + "/devices";
      local headers = {};
      headers["X-Api-Key"] <- "FEIMfjweiovm90283y3#*U)#@URvm";
      headers["Content-Type"] <- "application/json";
      local stringToSend = "";
      server.log(settings.len());
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
  }
  else {
    response.send(500, "Error");
  }
});



//Full res related stuff:
device.on("fullRes",function(data){
  local fullTailSend=array(10000);
  local fullBendSend=array(10000);
  for(local z=0;z<20000;z+=2){
    local currentReadinga=0;
    local currentReadingb=0;
    currentReadinga=((data.tail[z+1]*256)+data.tail[z])*(3.0/65536);
    currentReadingb=((data.bend[z+1]*256)+data.bend[z])*(3.0/65536);
    fullTailSend[z/2]=(currentReadinga);
    fullBendSend[z/2]=(currentReadingb);
  }
  server.log("AGENT HIGH RES POSTPROCESSING COMPLETE, SENDING DATA")
  local themac=data.macid
  firebase.write("/"+themac+"/"+data.timestamp+"/tail/" , fullTailSend);
  firebase.write("/" +themac+"/"+data.timestamp+"/bend/", fullBendSend);
  //data.data[0]["ts"].tostring().slice(0,5)+"/"
  server.log("SENT HIGH RES DATA")    
})


// Accept requests to open/close the valve
http.onrequest(function (request, response) {
    try {
      response.header("Access-Control-Allow-Origin", "*");
      /*
        if (request.query.action == "open") {
            server.save({action = request.query.action, time = request.query.time.tointeger(), duration = request.query.duration.tointeger()}); // seconds
            response.send(200, "OK");
        } else if (request.query.action == "close") {
            server.save({action = request.query.action, time = request.query.time.tointeger()});  // seconds
            response.send(200, "OK");
        } else {
            response.send(500, "Error: Action should be 'open' or 'close'.");
        }
      */
      if ("fullRes" in request.query) {
        // if it was, send the value of it to the device
        device.send("fullRes", request.query["fullRes"]);
        fullResSet = true
        server.log("Full Res Set to True")
      }
      // send a response back to whoever made the request
      response.send(200, "OK");
    } 
    catch (ex) {
      response.send(500, "Error: " + ex);
    }
});


//NOT reformatting the firebase class.

//created 15/5/1 "firebase test"
//renamed 15/5/18 "High Resolution Sampling" used with group 5 for capacitance test in bucket

// -----------------------------------------------------------------------------
class Firebase {
    // General
    db = null;              // the name of your firebase
    auth = null;            // Auth key (if auth is enabled)
    baseUrl = null;         // Firebase base url
    prefixUrl = "";         // Prefix added to all url paths (after the baseUrl and before the Path)
 
    // For REST calls:
    defaultHeaders = { "Content-Type": "application/json" };
    
    // For Streaming:
    streamingHeaders = { "accept": "text/event-stream" };
    streamingRequest = null;    // The request object of the streaming request
    data = null;                // Current snapshot of what we're streaming
    callbacks = null;           // List of callbacks for streaming request
    
    keepAliveTimer = null;      // Wakeup timer that watches for a dead Firebase socket
    kaPath = null;              // stream parameters to allow a restart on keepalive
    kaOnError = null;
 
    /***************************************************************************
     * Constructor
     * Returns: FirebaseStream object
     * Parameters:
     *      baseURL - the base URL to your Firebase (https://username.firebaseio.com)
     *      auth - the auth token for your Firebase
     **************************************************************************/
    constructor(_db, _auth = null, domain = "firebaseio.com") {
        const KEEP_ALIVE = 60;
        
        db = _db;
        baseUrl = "https://" + db + "." + domain;
        auth = _auth;
        data = {}; 
        callbacks = {};
    }
    
    /***************************************************************************
     * Attempts to open a stream
     * Returns: 
     *      false - if a stream is already open
     *      true -  otherwise
     * Parameters:
     *      path - the path of the node we're listending to (without .json)
     *      onError - custom error handler for streaming API 
     **************************************************************************/
    function stream(path = "", onError = null) {
        // if we already have a stream open, don't open a new one
        if (isStreaming()) return false;
 
        // Keep a backup of these for future reconnects
        kaPath = path;
        kaOnError = onError;
 
        if (onError == null) onError = _defaultErrorHandler.bindenv(this);
        streamingRequest = http.get(_buildUrl(path), streamingHeaders);
 
        streamingRequest.sendasync(
 
            // This is called when the stream exits
            function (resp) {
                streamingRequest = null;
                if (resp.statuscode == 307 && "location" in resp.headers) {
                    // set new location
                    local location = resp.headers["location"];
                    local p = location.find(".firebaseio.com")+16;
                    baseUrl = location.slice(0, p);
                    // server.log("Redirecting to " + baseUrl);
                    return stream(path, onError);
                } 
                else if (resp.statuscode == 28 || resp.statuscode == 429) {
                    // if we timed out, just reconnect after a small delay
                    imp.wakeup(1, function() {
                        return stream(path, onError);
                    }.bindenv(this))
                } 
                else {
                    // Reconnect unless the stream after an error
                    server.error("Stream closed with error " + resp.statuscode);
                    imp.wakeup(1, function() {
                        return stream(path, onError);
                    }.bindenv(this))
                }
            }.bindenv(this),
            
            
            // This is called whenever there is new data
            function(messageString) {
                
                // Tickle the keep alive timer
                if (keepAliveTimer) imp.cancelwakeup(keepAliveTimer);
                keepAliveTimer = imp.wakeup(KEEP_ALIVE, _keepAliveExpired.bindenv(this))
 
                // server.log("MessageString: " + messageString);
                local messages = _parseEventMessage(messageString);
                foreach (message in messages) {
                    // Update the internal cache
                    _updateCache(message);
                    
                    // Check out every callback for matching path
                    foreach (path,callback in callbacks) {
                        
                        if (path == "/" || path == message.path || message.path.find(path + "/") == 0) {
                            // This is an exact match or a subbranch 
                            callback(message.path, message.data);
                        } 
                        else if (message.event == "patch") {
                            // This is a patch for a (potentially) parent node
                            foreach (head,body in message.data) {
                                local newmessagepath = ((message.path == "/") ? "" : message.path) + "/" + head;
                                if (newmessagepath == path) {
                                    // We have found a superbranch that matches, rewrite this as a PUT
                                    local subdata = _getDataFromPath(newmessagepath, message.path, data);
                                    callback(newmessagepath, subdata);
                                }
                            }
                        } 
                        else if (message.path == "/" || path.find(message.path + "/") == 0) {
                            // This is the root or a superbranch for a put or delete
                            local subdata = _getDataFromPath(path, message.path, data);
                            callback(path, subdata);
                        } 
                        else {
                            // server.log("No match for: " + path + " vs. " + message.path);
                        }
                        
                    }
                }
            }.bindenv(this),
            
            // Stay connected as long as possible
            NO_TIMEOUT
            
        );
        
        // Tickle the keepalive timer
        if (keepAliveTimer) imp.cancelwakeup(keepAliveTimer);
        keepAliveTimer = imp.wakeup(KEEP_ALIVE, _keepAliveExpired.bindenv(this))
        
        // server.log("New stream successfully started")
        
        // Return true if we opened the stream
        return true;
    }
    
 
    /***************************************************************************
     * Returns whether or not there is currently a stream open
     * Returns: 
     *      true - streaming request is currently open
     *      false - otherwise
     **************************************************************************/
    function isStreaming() {
        return (streamingRequest != null);
    }
    
    /***************************************************************************
     * Closes the stream (if there is one open)
     **************************************************************************/
    function closeStream() {
        if (streamingRequest) { 
            // server.log("Closing stream")
            streamingRequest.cancel();
            streamingRequest = null;
        }
    }
    
    /***************************************************************************
     * Registers a callback for when data in a particular path is changed.
     * If a handler for a particular path is not defined, data will change,
     * but no handler will be called
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're listending to (without .json)
     *      callback - a callback function with two parameters (path, change) to be 
     *                 executed when the data at path changes
     **************************************************************************/
    function on(path, callback) {
        if (path.len() > 0 && path.slice(0, 1) != "/") path = "/" + path;
        if (path.len() > 1 && path.slice(-1) == "/") path = path.slice(0, -1);
        callbacks[path] <- callback;
    }
    
    /***************************************************************************
     * Reads a path from the internal cache. Really handy to use in an .on() handler
     **************************************************************************/
    function fromCache(path = "/") {
        local _data = data;
        foreach (step in split(path, "/")) {
            if (step == "") continue;
            if (step in _data) _data = _data[step];
            else return null;
        }
        return _data;
    }
     
    /***************************************************************************
     * Reads data from the specified path, and executes the callback handler
     * once complete.
     *
     * NOTE: This function does NOT update firebase.data
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're reading
     *      callback - a callback function with one parameter (data) to be 
     *                 executed once the data is read
     **************************************************************************/    
     function read(path, callback = null) {
        http.get(_buildUrl(path), defaultHeaders).sendasync(function(res) {
            if (callback) {
                local data = null;
                try {
                    data = http.jsondecode(res.body);
                } catch (err) {
                    server.error("Read: JSON Error: " + res.body);
                    return;
                }
                callback(data);
            } else if (res.statuscode != 200) {
                server.error("Read: Firebase response: " + res.statuscode + " => " + res.body)
            }
        }.bindenv(this));
    }
    
    /***************************************************************************
     * Pushes data to a path (performs a POST)
     * This method should be used when you're adding an item to a list.
     * 
     * NOTE: This function does NOT update firebase.data
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're pushing to
     *      data     - the data we're pushing
     **************************************************************************/    
    function push(path, data, priority = null, callback = null) {
        if (priority != null && typeof data == "table") data[".priority"] <- priority;
        http.post(_buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (callback) callback(res);
            else if (res.statuscode != 200) {
                server.error("Push: Firebase responded " + res.statuscode + " to changes to " + path)
            }
        }.bindenv(this));
    }
    
    /***************************************************************************
     * Writes data to a path (performs a PUT)
     * This is generally the function you want to use
     * 
     * NOTE: This function does NOT update firebase.data
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're writing to
     *      data     - the data we're writing
     **************************************************************************/    
    function write(path, data, callback = null) {
        http.put(_buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (callback) callback(res);
            else if (res.statuscode != 200) {
                server.error("Write: Firebase responded " + res.statuscode + " to changes to " + path)
            }
        }.bindenv(this));
    }
    
    /***************************************************************************
     * Updates a particular path (performs a PATCH)
     * This method should be used when you want to do a non-destructive write
     * 
     * NOTE: This function does NOT update firebase.data
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're patching
     *      data     - the data we're patching
     **************************************************************************/    
    function update(path, data, callback = null) {
        http.request("PATCH", _buildUrl(path), defaultHeaders, http.jsonencode(data)).sendasync(function(res) {
            if (callback) callback(res);
            else if (res.statuscode != 200) {
                server.error("Update: Firebase responded " + res.statuscode + " to changes to " + path)
            }
        }.bindenv(this));
    }
    
    /***************************************************************************
     * Deletes the data at the specific node (performs a DELETE)
     * 
     * NOTE: This function does NOT update firebase.data
     * 
     * Returns: 
     *      nothing
     * Parameters:
     *      path     - the path of the node we're deleting
     **************************************************************************/        
    function remove(path, callback = null) {
        http.httpdelete(_buildUrl(path), defaultHeaders).sendasync(function(res) {
            if (callback) callback(res);
            else if (res.statuscode != 200) {
                server.error("Delete: Firebase responded " + res.statuscode + " to changes to " + path)
            }
        });
    }
    
    /************ Private Functions (DO NOT CALL FUNCTIONS BELOW) ************/
    // Builds a url to send a request to
    function _buildUrl(path) {
        // Normalise the /'s
        // baseURL = <baseURL>
        // prefixUrl = <prefixURL>/
        // path = <path>
        if (baseUrl.len() > 0 && baseUrl[baseUrl.len()-1] == '/') baseUrl = baseUrl.slice(0, -1);
        if (prefixUrl.len() > 0 && prefixUrl[0] == '/') prefixUrl = prefixUrl.slice(1);
        if (prefixUrl.len() > 0 && prefixUrl[prefixUrl.len()-1] != '/') prefixUrl += "/";
        if (path.len() > 0 && path[0] == '/') path = path.slice(1);
        
        local url = baseUrl + "/" + prefixUrl + path + ".json";
        url += "?ns=" + db;
        if (auth != null) url = url + "&auth=" + auth;
        
        return url;
    }
 
    // Default error handler
    function _defaultErrorHandler(errors) {
        foreach (error in errors) {
            server.error("ERROR " + error.code + ": " + error.message);
        }
    }
 
    // No keep alive has been seen for a while, lets reconnect
    function _keepAliveExpired() {
        keepAliveTimer = null;
        server.error("Keep alive timer expired. Reconnecting stream.")
        closeStream();
        stream(kaPath, kaOnError);
    }    
    
    // parses event messages
    function _parseEventMessage(text) {
        
        // split message into parts
        local alllines = split(text, "\n");
        if (alllines.len() < 2) return [];
 
        local returns = [];
        for (local i = 0; i < alllines.len(); ) {
            local lines = [];
            
            lines.push(alllines[i++]);
            lines.push(alllines[i++]);
            if (i < alllines.len() && alllines[i+1] == "}") {
                lines.push(alllines[i++]);
            }
            
            // Check for error conditions
            if (lines.len() == 3 && lines[0] == "{" && lines[2] == "}") {
                local error = http.jsondecode(text);
                server.error("Firebase error message: " + error.error);
                continue;
            }
    
            // get the event
            local eventLine = lines[0];
            local event = eventLine.slice(7);
            // server.log(event);
            if(event.tolower() == "keep-alive") continue;
            
            // get the data
            local dataLine = lines[1];
            local dataString = dataLine.slice(6);
        
            // pull interesting bits out of the data
            local d;
            try {
                d = http.jsondecode(dataString);
            } catch (e) {
                server.error("Exception while decoding (" + dataString.len() + " bytes): " + dataString);
                throw e;
            }
    
            // return a useful object
            returns.push({ "event": event, "path": d.path, "data": d.data });
        }
        
        return returns;
    }
 
    // Updates the local cache
    function _updateCache(message) {
        
        // server.log(http.jsonencode(message)); 
        
        // base case - refresh everything
        if (message.event == "put" && message.path == "/") {
            data = (message.data == null) ? {} : message.data;
            return data
        }
 
        local pathParts = split(message.path, "/");
        local key = pathParts.len() > 0 ? pathParts[pathParts.len()-1] : null;
 
        local currentData = data;
        local parent = data;
        local lastPart = "";
 
        // Walk down the tree following the path
        foreach (part in pathParts) {
            if (typeof currentData != "array" && typeof currentData != "table") {
                // We have orphaned a branch of the tree
                if (lastPart == "") {
                    data = {};
                    parent = data;
                    currentData = data;
                } else {
                    parent[lastPart] <- {};
                    currentData = parent[lastPart];
                }
            }
            
            parent = currentData;
            
            // NOTE: This is a hack to deal with a quirk of Firebase
            // Firebase sends arrays when the indicies are integers and its more efficient to use an array.
            if (typeof currentData == "array") {
                part = part.tointeger();
            }
            
            if (!(part in currentData)) {
                // This is a new branch
                currentData[part] <- {};
            }
            currentData = currentData[part];
            lastPart = part;
        }
        
        // Make the changes to the found branch
        if (message.event == "put") {
            if (message.data == null) {
                // Delete the branch
                if (key == null) {
                    data = {};
                } else {
                    if (typeof parent == "array") {
                        parent[key.tointeger()] = null;
                    } else {
                        delete parent[key];
                    }
                }
            } else {
                // Replace the branch
                if (key == null) {
                    data = message.data;
                } else {
                    if (typeof parent == "array") {
                        parent[key.tointeger()] = message.data;
                    } else {
                        parent[key] <- message.data;
                    }
                }
            }
        } else if (message.event == "patch") {
            foreach(k,v in message.data) {
                if (key == null) {
                    // Patch the root branch
                    data[k] <- v;
                } else {
                    // Patch the current branch
                    parent[key][k] <- v;
                }
            }
        }
        
        // Now clean up the tree, removing any orphans
        _cleanTree(data);
    }
 
    // Cleans the tree by deleting any empty nodes
    function _cleanTree(branch) {
        foreach (k,subbranch in branch) {
            if (typeof subbranch == "array" || typeof subbranch == "table") {
                _cleanTree(subbranch)
                if (subbranch.len() == 0) delete branch[k];
            }
        }
    }
 
    // Steps through a path to get the contents of the table at that point
    function _getDataFromPath(c_path, m_path, m_data) {
        
        // Make sure we are on the right branch
        if (m_path.len() > c_path.len() && m_path.find(c_path) != 0) return null;
        
        // Walk to the base of the callback path
        local new_data = m_data;
        foreach (step in split(c_path, "/")) {
            if (step == "") continue;
            if (step in new_data) {
                new_data = new_data[step];
            } else {
                new_data = null;
                break;
            }
        }
        
        // Find the data at the modified branch but only one step deep at max
        local changed_data = new_data;
        if (m_path.len() > c_path.len()) {
            // Only a subbranch has changed, pick the subbranch that has changed
            local new_m_path = m_path.slice(c_path.len())
            foreach (step in split(new_m_path, "/")) {
                if (step == "") continue;
                if (step in changed_data) {
                    changed_data = changed_data[step];
                } else {
                    changed_data = null;
                }
                break;
            }
        }
 
        return changed_data;
    }
    
}
 
firebase <- Firebase("fiery-heat-4911", "Z8weueFHsGRl7TOEEbWrVgak6Ua1RuIC12mF9PEG");















