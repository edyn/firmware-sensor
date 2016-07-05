////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
//
// Imp Agent code runs on a server in the Imp Cloud. 
// It forwards data from the Imp Device to the Edyn server.
////////////////////////////////////////////////////////////
#require "Firebase.class.nut:1.0.0"
#require "Loggly.class.nut:1.0.1"
macAgentSide <- imp.configparams.deviceid;

fullResSet <- false
THEMACADDRESSAGENTSIDE<-"unknownMacAddress"

firebase <- Firebase("fiery-heat-4911", "Z8weueFHsGRl7TOEEbWrVgak6Ua1RuIC12mF9PEG");
bearerAuth <- "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzY29wZXMiOlsicHVibGljIiwidmFsdmU6YWdlbnQiXSwiaWF0IjoxNDU1NzM4MjY4LCJzdWIiOiJhcHA6dmFsdmUtYWdlbnQifQ.-BKIywHrpbtNo2xuYhcZ-4w5itBFQMM0KHQZmXcYgcM";

logglyKey <- "1890ff8f-0c0a-4ca0-b2f4-74f8f3ea469b"
loggly <- Loggly(logglyKey, { 
    "tags" : "valveLogs",
    "timeout" : 60,
    "limit" : 20 //arbitrary 
});

globalDataStore <- [];
agentSendBackoffTimes <- [0.1, 1.0, 2.0, 4.0, 8.0, 15.0, 30.0, 60.0];
//agentRetryActive prevents multiple chains of retrySendingDataIfNeeded
agentRetryActive <- false;
const FAILED_READINGS_WARNING = 100;
agentBackoffIndex <- 0;



function addLogglyDefault(logTable){
  logTable.macAddress <- macAgentSide;
  logTable.sourceGroup <- "Firmware";
  logTable.env <- "Sensor_Loggly";
  return logTable
}

function logglyLog(logTable, level){
  try{
    //if it's not a table, don't try anything
    if(type(logTable) != type({})){
      loggly.warn({"SensorAgentWarning" : "LogglyLog passed data other than a table"})
    } else {
      server.log(type(logTable))
      //add defaults to the table
      logTable = addLogglyDefault(logTable);
      //log based on the log level
      if(level == "Log"){
        loggly.log(logTable);
      } else if (level == "Warning"){
        loggly.warn(logTable);
      } else if (level == "Error"){
        loggly.error(logTable);
      } else {
        loggly.warning({"SensorAgentWarning" : "Invalid level passed to logglyLog"});
        loggly.error(logTable);
      }
    }
  } catch(error) {
    server.log("Loggly Log encountered an error! " + error);
  }
}

//put the agent url on loggly. This will happen WHENEVER the agent is restarted
logglyLog({"agentURL" : http.agenturl()}, "Log");

device.on("logglyLog", 
  function(logTable){logglyLog(logTable, "Log")}
);
device.on("logglyWarn", 
  function(logTable){logglyLog(logTable, "Warning")}
);
device.on("logglyError", 
  function(logTable){logglyLog(logTable, "Error")}
);

function failedSendTable(targetURL, body, statuscode){
  local outputTable = {};
  outputTable.url <- targetURL;
  outputTable.body <- http.jsondecode(body);
  outputTable.statusCode <- statuscode;
  //Use this to build table with information we want on failed http requests.
  return outputTable

}

// Send data to the readings API
function send_data_json_node(data) {
  server.log(http.jsonencode(data));
  local readings_url = "https://api.sensor.prod.edyn.com/readings";
  local headers = {
    "Content-Type":"application/json",
    "User-Agent":"Imp",
    "Authorization" : bearerAuth,
    "X-Api-Key":"staging-electric-imp-api-key"
  };
  local req = http.post(readings_url, headers, http.jsonencode(data));
  local res = req.sendsync();
  //failed send to backend
  if (res.statuscode < 200 || res.statuscode > 203) {
    // TODO: retry?
    server.log("Error sending message to Postgres database.");
    local logglyWarnTable = failedSendTable(readings_url, res.body, res.statuscode);
    logglyLog(logglyWarnTable, "Warning");
  } else {
    server.log("Data sent successfully to Postgres database.");
  }
}

//this function appears to be unused
function processResponse(incomingDataTable) {
  // This is the completed-request callback function.
  if (incomingDataTable.statuscode != 200) {
    // TODO: retry?
    // server.log("error sending message: " + res.body);
    server.log("API status code: " + res.statuscode);
    // server.log(res.body);
    // server.log("error sending message: " + res.body.slice(0,40));
    server.log("Error saving device location in DB.");
    local logglyWarnTable = failedSendTable(res.statuscode);
    logglyLog(logglyWarnTable, "Warning");
  }
  else {
    server.log("Device location saved in DB successfully.");
  }
}


// Invoked when the device calls agent.send("data", ...)
device.on("data", function(data) {
  // data[sd] <- [1, 2];
  if(!("power_data" in data)) {//WITHOUT powerdata
    // data[sd] <- [1, 2];
    local dataToSend = data;
    local dataToSendNode = {};
    dataToSendNode.uuid <- data.device;
    THEMACADDRESSAGENTSIDE=data.device
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
    newPoint.rssi <- point.r;
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
    else 
    {
        server.log("NTC STAT IS:")
        server.log(ntc_stat)
        newPoint.ntc_stat <- "NTC BUGGED OUT"
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
  } else {//WITH powerdata
    //SO MUCH DRY
    //Does this else even happen? it seems like it would throw errors if it did...
    //explanation: it seems to interpret power data, but it's only happens if powerData isn't present in the reading
    //I *think* it's here because we transitioned into powerData being it's own table, so this was here for some reason?
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
    } else {
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
    newPoint.rssi <- point.r;
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
    else 
    {
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
  
  
  if(fullResSet)
    {
        server.log("here")
        device.send("fullRes", {data="1"})
        server.log("Full Res Set request sent")
        server.log("Full Res Set To False")
        fullResSet=false
    }
}) 

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

//Full res related stuff:
device.on("fullRes",function(data)
{
    
    local fullTailSend=array(10000);
    local fullBendSend=array(10000);
    for(local z=0;z<20000;z+=2)
    {
        local currentReadinga=0
        local currentReadingb=0
        currentReadinga=((data.tail[z+1]*256)+data.tail[z])*(3.0/65536)
        currentReadingb=((data.bend[z+1]*256)+data.bend[z])*(3.0/65536)
        fullTailSend[z/2]=(currentReadinga)
        fullBendSend[z/2]=(currentReadingb)
    }
    server.log("AGENT HIGH RES POSTPROCESSING COMPLETE, SENDING DATA")
            local themac=data.macid
            firebase.write("/"+themac+"/"+data.timestamp+"/tail/" , fullTailSend);
            firebase.write("/" +themac+"/"+data.timestamp+"/bend/", fullBendSend);
            //data.data[0]["ts"].tostring().slice(0,5)+"/"
            server.log("SENT HIGH RES DATA")

    
}
)


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
        }*/
        if ("fullRes" in request.query) {
        // if it was, send the value of it to the device
            device.send("fullRes", request.query["fullRes"]);
            fullResSet = true
            server.log("Full Res Set to True")
        }
        // send a response back to whoever made the request
        response.send(200, "OK");
    } catch (ex) {
        response.send(500, "Error: " + ex);
    }
});


 








