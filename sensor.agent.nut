////////////////////////////////////////////////////////////
// Edyn - Soil IQ - Probe
//
// Imp Agent code runs on a server in the Imp Cloud.
// It forwards data from the Imp Device to the Edyn server.
////////////////////////////////////////////////////////////
#require "Firebase.class.nut:1.0.0"
#require "Loggly.class.nut:1.0.1"
macAgentSide <- imp.configparams.deviceid;

const agentBackendSettingsPassword = "GiftShop405";


//High resolution related
highResFirebase <- "fiery-heat-4911";
highResToken <- "Z8weueFHsGRl7TOEEbWrVgak6Ua1RuIC12mF9PEG";
firebase <- Firebase(highResFirebase, highResToken);
GlobalTest <- 1
fullResSet <- false
THEMACADDRESSAGENTSIDE<-"unknownMacAddress"

//backend readings
readings_url <- "https://api.sensor.prod.edyn.com/readings";
bearerAuth <- "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzY29wZXMiOlsicHVibGljIiwidmFsdmU6YWdlbnQiXSwiaWF0IjoxNDU1NzM4MjY4LCJzdWIiOiJhcHA6dmFsdmUtYWdlbnQifQ.-BKIywHrpbtNo2xuYhcZ-4w5itBFQMM0KHQZmXcYgcM";

//backend agent-url firebase related
macToAgentFirebase <- "https://mactoagent.firebaseio.com/";
macToAgentCurrentConfigPath <- "current-config/";
macToAgentConfigOverridePath <- "config-override/"
macToAgentAuth <- "aMB4B4eVNwl6fUQwHy9OlE5BUcGVUoad8dnn4HCu";
impApiKey <- "staging-electric-imp-api-key";

//needs to change depending on actual hardware version
const HARDWARE_VERSION = "0.0.2";
//no real rules about when this needs to change yet
const FIRMWARE_VERSION = "0.0.1";
OS_VERSION <- "unknown";

//loggly
logglyKey <- "1890ff8f-0c0a-4ca0-b2f4-74f8f3ea469b"
loggly <- Loggly(logglyKey, {
    "tags" : "sensorLogs",
    "timeout" : 60,
    "limit" : 20 //arbitrary
});

const SCHEMA_VERSION = "0.1"

// TODO: Dustin, this was missing an 's' for a long time.
// What do you think the implications were?
function addLogglyDefaults(logTable){
  if (!("machineType" in logTable)) {
    logTable.machineType <- "agent";
  }
  logTable.macAddress <- macAgentSide;
  logTable.sourceGroup <- "Firmware";
  logTable.env <- "Production";
  return logTable
}

function serverLogTable(inputTable, level){
    try{
        //todo: function calls itself recursively
        server.log("\nLoggly " + level + " table:")
        foreach (key,value in inputTable){
            if(typeof(value) == typeof({})){
                server.log("\tsubTable '" + key + "' found in table:")
                foreach (subKey,subValue in value){
                    server.log("\t\t" + subKey + " : " + subValue)
                }
            } else if(typeof(value) == typeof([])){
                if(value.len()){
                    for(local x = 0; x < value.len(); x++){
                        if(typeof(value[x]) != typeof([]) && typeof(value[x]) != typeof({})){
                            server.log("\tArray " + key + " index " + x " : " + value[x]);
                        } else {
                            //easiest way to log these subtable/subarrays without throwing error
                            server.log("\tArray " + key + " index " + x " : " + http.jsonencode(value[x]));
                        }
                    }
                }
            } else {
                server.log("\t" + key + " : " + value)
            }
        }
    } catch(error) {
        //using library definition rather than logglyLog function
        loggly.error({
          "message" : "Error in serverLogTable",
          "error" : error,
          "tableAsJson" : http.jsonencode(inputTable)
        })
    }
}


function logglyLog(logTable = {"message" : "empty log table passed to logglyLog"}, level = "Log", serverLog = true){
    try{
        if(type(logTable) != type({})){
            loggly.warn({"agentWarning" : "non-table passed to logglyLog"});
            server.log("NON TABLE PASSED TO LOGGLYLOG!")
        } else {
            logTable = addLogglyDefaults(logTable);
            if(serverLog){
                serverLogTable(logTable, level)
            }
            if(level == "Log"){
                loggly.log(logTable);
            } else if (level == "Warning") {
                loggly.warn(logTable);
            } else if (level == "Error"){
                loggly.error(logTable);
            } else {
                loggly.warn({
                  "agentWarning" : "Invalid level passed to logglyLog"
                });
            }
        }
    } catch (error) {
        server.log("error in logglyLog")
        loggly.error({
            "function" : "logglyLog",
            "error" : error
        });
    }
}


function recordBackendSettings(){
    try{
        local macToAgentURL = macToAgentFirebase + macToAgentCurrentConfigPath + macAgentSide + ".json?auth=" + macToAgentAuth;
        local headers = {
            "User-Agent":"Imp"
        };
        local req = http.put(macToAgentURL, headers, http.jsonencode({
          "readingsApi" : readings_url,
          "bearerAuth" : bearerAuth,
          "firebase" : highResFirebase,
          "firebaseToken" : highResToken,
          "agentURL" : http.agenturl(),
          "impApiKey" : impApiKey
        }));
        local res = req.sendsync();
        //TODO: make generic handling function for HTTP requests
        if(res.statuscode < 200 || res.statuscode > 204){
            server.log("Failed to save backend settings to firebase")
            logglyLog(
                {
                    "message" : "Failed to save backend settings",
                    "statuscode" : res.statuscode,
                    "agentURL" :  http.agenturl()
                }, "Warning");
        } else {
            server.log("Saved backend settings to firebase")
        }
    } catch(error) {
        server.log("error in saveBackendSettings: " + error)
    }
}

function loadBackendSettings(){
    try{
        local macToAgentURL = macToAgentFirebase + macToAgentConfigOverridePath + macAgentSide +".json?auth=" + macToAgentAuth;
        local headers = {
            "User-Agent":"Imp"
        };
        local req = http.get(macToAgentURL, headers);
        local res = req.sendsync();
        //TODO: make generic handling function for HTTP requests
        if(res.statuscode < 200 || res.statuscode > 204){
            server.log("Failed to load backend settings " + res.statuscode)
            logglyLog(
                {
                    "message" : "Failed to load backend settings",
                    "statuscode" :res.statuscode,
                    "agentURL" :  http.agenturl()
                }, "Warning");
        } else {
            server.log("Loaded backend settings, body:")
            local bodyResponseTable = http.jsondecode(res.body);
            server.log(bodyResponseTable)
            if(bodyResponseTable != null){
                if("readingsApi" in bodyResponseTable){
                    server.log("changing readingsApi");
                    readings_url = bodyResponseTable.readingsApi;
                }
                if("bearerAuth" in bodyResponseTable){
                    server.log("changing bearerAuth");
                    bearerAuth = bodyResponseTable.bearerAuth;
                }
                if("firebase" in bodyResponseTable){
                    server.log("changing firebase root");
                    highResFirebase = bodyResponseTable.firebase;
                }
                if("firebaseToken" in bodyResponseTable){
                    server.log("changing firebase token");
                    highResToken = bodyResponseTable.firebaseToken;
                }
                if("impApiKey" in bodyResponseTable){
                    server.log("changing imp api key");
                    impApiKey = bodyResponseTable.impApiKey;
                }
            }
        }
    } catch(error) {
        server.log("error in loadBackendSettings: " + error)
    }
}

//put the agent url on loggly. This will happen WHENEVER the agent is restarted
logglyLog({"agentURL" : http.agenturl()}, "Log");

function attributeLogToDevice(logTable){
  logTable.machineType <- "device"
  return logTable
}

device.on("logglyLog",
  function(logTable){
    logTable = attributeLogToDevice(logTable);
    logglyLog(logTable, "Log");
  }
);
device.on("logglyWarn",
  function(logTable){
    logTable = attributeLogToDevice(logTable);
    logglyLog(logTable, "Warning");
  }
);
device.on("logglyError",
  function(logTable){
    logTable = attributeLogToDevice(logTable);
    logglyLog(logTable, "Error");
  }
);

function failedSendTable(targetURL, body, statuscode){
  local outputTable = {};
  outputTable.url <- targetURL;
  outputTable.body <- http.jsondecode(body);
  outputTable.statusCode <- statuscode;
  //Use this to build table with information we want on failed http requests.
  return outputTable

}

loadBackendSettings();
recordBackendSettings();

// Send data to the readings API
function send_data_json_node(data) {
  server.log(http.jsonencode(data));
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


//AKA wall_i_lim:
function processCurrentLimit(input){
  //input used to be data.power_data[1]
    input = (input & 0x1f);
    if (input == 0x00) return "100mA Max (USB Low Power)";
    if (input == 0x01) return "500mA Max (USB High Power)";
    if (input == 0x02) return "600mA Max";
    if (input == 0x03) return "700mA Max";
    if (input == 0x04) return "800mA Max";
    if (input == 0x05) return "900mA Max (USB 3.0)";
    if (input == 0x06) return "1000mA Typical";
    if (input == 0x07) return "1250mA Typical";
    if (input == 0x08) return "1500mA Typical";
    if (input == 0x09) return "1750mA Typical";
    if (input == 0x0A) return "2000mA Typical";
    if (input == 0x0B) return "2250mA Typical";
    if (input == 0x0C) return "2500mA Typical";
    if (input == 0x0D) return "2750mA Typical";
    if (input == 0x0E) return "3000mA Typical";
    if (input == 0x0F) return "2.5mA Max (USB Suspend)";
    if (input == 0x1F) return "SELECT CLPROG1";
    //TODO: add loggly warning here
    return "CurrentLimit Not Found";
}

function processVFloat(input){
    //input was data.power_data[2]
    local vFloat = (input & 0xc) >> 2;
    if (vFloat == 0x0) return 3.45;
    if (vFloat == 0x1) return 3.55;
    if (vFloat == 0x2) return 3.60;
    if (vFloat == 0x3) return 3.80;
    return -1.0;
}

function processTimer(input){
    //input was data.power_data[1]
    // In minutes, different than data sheet
    local timer = (input & 0x60) >> 5;
    if (timer == 0x0) return 60;
    if (timer == 0x1) return 240;
    if (timer == 0x2) return 15;
    if (timer == 0x3) return 30;
    //TODO: add loggly warning here
    return -1;
}

function processICharge(input){
    //input used to be data.power_data[2]
    local iCharge = ((input & 0xf0) >> 4).tofloat();
    local convertedICharge = ((iCharge-1)*6.25)+12.5
    if (convertedICharge < 12.49) convertedICharge = 0.0;
    return convertedICharge
}

function processCXSet(input){
    //input was data.power_data[2]
    local cxSet = (input & 0x3);
    if (cxSet == 0x0) return 10;
    if (cxSet == 0x1) return 20;
    if (cxSet == 0x2) return 2;
    if (cxSet == 0x3) return 5;
    //TODO: add loggly warning here
    return -1;
}

function processChargerStatus(input){
    //input used to be data.power_data[3]
    local chargerStatus = (input & 0xe0) >> 5;
    if (chargerStatus == 0x0) return "Charger Off";
    if (chargerStatus == 0x1) return "Low Battery Voltage";
    if (chargerStatus == 0x2) return "Constant Current";
    if (chargerStatus == 0x3) return "Constant Voltage, VPROG>VC/X";
    if (chargerStatus == 0x4) return "Constant Voltage, VPROG<VC/X";
    if (chargerStatus == 0x6) return "NTC TOO COLD, Charging Paused";
    if (chargerStatus == 0x7) return "NTC HOT FAULT, Charging Paused";
    //TODO: add loggly warning here
    return "chargerStatus Not Found";
}

function processNTCStat(input){
  //input used to be data.power_data[3]
    local ntcStat = (input & 0x6) >> 1;
    if (ntcStat == 0x0) return "NTC Normal";
    if (ntcStat == 0x1) return "NTC_TOO_COLD";
    if (ntcStat == 0x3) return "NTC_HOT_FAULT";
    return "NTC BUGGED OUT";
}

function processInputUVCL(input){
    //returns a bool
    //input used to be data.power_data[0]
    return (input & 0x80) != 0x00;
}

function getOrSetLocationSettings(){

}

function processPowerData(inputPowerDataRegisters){
    local returnDataTable = {};
    returnDataTable.disable_input_uvcl <- processInputUVCL(inputPowerDataRegisters[0]);
    returnDataTable.wall_i_lim <- processCurrentLimit(inputPowerDataRegisters[1]);
    returnDataTable.timer <- processTimer(inputPowerDataRegisters[1]);
    returnDataTable.i_charge <- processICharge(inputPowerDataRegisters[2]);
    returnDataTable.v_float <- processVFloat(inputPowerDataRegisters[2]);
    returnDataTable.c_x_set <- processCXSet(inputPowerDataRegisters[2]);
    returnDataTable.charger_status <- processChargerStatus(inputPowerDataRegisters[3]);
    returnDataTable.ntc_stat <- processNTCStat(inputPowerDataRegisters[3]);
    returnDataTable.low_bat <- (inputPowerDataRegisters[3] & 0x1) != 0x00;
    returnDataTable.ext_pwr_good <- (inputPowerDataRegisters[4] & 0x80) != 0x00;
    returnDataTable.wall_sns_good <- (inputPowerDataRegisters[4] & 0x20) != 0x00;
    returnDataTable.at_input_ilim <- (inputPowerDataRegisters[4] & 0x10) != 0x00;
    returnDataTable.ovp_active <- (inputPowerDataRegisters[4] & 0x4) != 0x00;
    returnDataTable.bad_cell <- (inputPowerDataRegisters[4] & 0x1) != 0x00;
    returnDataTable.ntc_val <- ((inputPowerDataRegisters[5] & 0xfe) >> 1).tointeger();
    returnDataTable.ntc_warning <- (inputPowerDataRegisters[5] & 0x1) != 0x00;
    returnDataTable.input_uvcl_active <- processInputUVCL(inputPowerDataRegisters[0]);
    return returnDataTable;
}

function processWifiData(inputDeviceData){
    local returnTable = {};
    local powerData = processPowerData(inputDeviceData.power_data);
    returnTable = powerData;
    //add the device metadata
    returnTable.firmwareVersion <- FIRMWARE_VERSION;
    returnTable.hardwareVersion <- HARDWARE_VERSION;
    returnTable.osVersion <- OS_VERSION;
    return returnTable;
}

function processWakeReason(integerWakeReason){
    switch(integerWakeReason){
      case 0:
          return "WAKEREASON_POWER_ON"
      case 1:
          return "WAKEREASON_TIMER"
      case 2:
          return "WAKEREASON_SW_RESET"
      case 3:
          return "WAKEREASON_PIN"
      case 4:
          return "WAKEREASON_NEW_SQUIRREL"
      case 5:
          return "WAKEREASON_SQUIRREL_ERROR"
      case 6:
          return "WAKEREASON_NEW_FIRMWARE"
      case 7:
          return "WAKEREASON_SNOOZE"
      case 8:
          return "WAKEREASON_HW_RESET"
      case 9:
          return "WAKEREASON_BLINKUP"
    }
    //this is not accepted by the backend yet but should NEVER happen:
    return "WAKEREASON_NOT_FOUND"
}

function processRegularData(inputData){
    local returnData = [];
    //don't know what this is for
    //foreach (origPoint in inputData.data) {
    //    origPoint.sd <- [1];
    //}
    foreach (point in inputData.data) {
        local newPoint = {};
        newPoint.timestamp <- point.ts;
        newPoint.battery <- point.b;
        newPoint.humidity <- point.h;
        newPoint.temperature <- point.t;
        newPoint.electrical_conductivity <- point.m;
        newPoint.light <- point.l;
        newPoint.capacitance <- point.c;
        newPoint.rssi <- point.r;
        newPoint.wakeReason <- processWakeReason(point.w);
        returnData.append(newPoint);
    }
    return returnData;
}

function processAndSendDeviceData(deviceData){
    try{
        //construct the table
        local payLoadTable = {};
        payLoadTable.macAddress <- macAgentSide;
        payLoadTable.schemaVersion <- SCHEMA_VERSION;
        //wake data is an array of tables [{},{},{}]
        payLoadTable.wakeData <- processRegularData(deviceData);
        //wifiData is a terrible name
        //also wifiData is a single table, a more appropriate name might be powerData or ltcData or powerManagerData
        payLoadTable.wifiData <- processWifiData(deviceData);
        send_data_json_node(payLoadTable);
    } catch (error) {
        logglyLog({
            "function" : "processAndSendDeviceData",
            "message" : "a sub function may have failed",
            "errorMessage" : error
        }, "Error");
    }
}

device.on("data", processAndSendDeviceData);

function addColons(bssid) {
  local result = bssid.slice(0, 2);

  for (local i = 2; i < 12; i += 2) {
    result += ":" + bssid.slice(i, (i + 2));
  }

  return result;
}

device.on("syncOSVersionFromDevice", function(osVersion){
    OS_VERSION = osVersion;
})

device.onconnect(function() {
  // Any new blinkup will create a new agent, and hence the agent storage
  // (accessed with server.load/save) will be empty.
  // When the agent starts it can check to see if this is empty and
  // if so, send a message to the device.

  // Load the settings table in from permanent storage
  local settings = server.load();

  if(OS_VERSION == "unknown"){
      device.send("syncOSVersion", []);
  }

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


http.onrequest(function (request, response) {
    try {
        response.header("Access-Control-Allow-Origin", "*");
        if("path" in request){
            if(request.path == "/device-type" || request.path == "/device-type/"){
                if("internal-auth" in request.headers){
                    if(request.headers["internal-auth"] == INTERNAL_AUTH){
                        response.send(200, http.jsonencode({"deviceType" : "sensor"}));
                        return
                    } else {
                        response.send(403, http.jsonencode({"error" : "Bad Password"}));
                        return
                    }
                } else {
                    response.send(403, http.jsonencode({"error" : "Missing Password"}));
                    return
                }
            }
        }
 
        if ("fullRes" in request.query) {
        // if it was, send the value of it to the device
            device.send("fullRes", request.query["fullRes"]);
            fullResSet = true
            response.send(200, "OK");
            server.log("Full Res Set to True")
            return
        }

        //note that on the sensor the only action you can take is restarting (or high res)
        if("password" in request.query){
          if(request.query["password"] == agentBackendSettingsPassword){
            if("restartAgent" in request.query){
              response.send(200, "OK");
              server.restart();
              return
            }
          }
        }
        // send a response back to whoever made the request
        response.send(403, http.jsonencode({"error" : "no arguments given"}));
    } catch (ex) {
        response.send(500, "Error: " + ex);
    }
});
