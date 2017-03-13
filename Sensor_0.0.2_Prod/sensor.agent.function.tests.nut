server.log("Device running functional tests")
//todo before release: add exponential error test

mainRunNumber <- 1;
scheduleFromBackend <- null
currentTestName <- "0"

//function that runs over and over, once for each event in a sequence:
function runMain(runTable){
    mainRunNumber += 1;
    server.log("\n\nMAIN RUN NUMBER: " + (mainRunNumber - 1))
    server.log(http.jsonencode({"wakeReason" : runTable.wakeReason, "online" : runTable.online, "battery" : runTable.battery, "fakeTime" : runTable.fakeTime, "mute" : runTable.mute}))
    device.send("runMain", {"wakeReason" : runTable.wakeReason, "connectSuccess" : runTable.connectSuccess, "online" : runTable.online, "battery" : runTable.battery, "fakeTime" : runTable.fakeTime, "mute" : runTable.mute, "throwError" : runTable.throwError});
}

//adding null as as first index so this table is 1 indexed
expectedResultsArray <- [null]
runMainSequenceArray <- [null]

//Tracks names to make debugging easier:
testName <- "Null"
testNameChangeArray <- {}

//wake reason constants not defined by eimp on agent (for no good reason) but it frees us up to create our own!
const WR_BOOT = 0;
const WR_TIMER = 1;
const WR_SW_RESET = 2;
const WR_BUTTON = 3;
const WR_NEW_SQUIRREL = 4;
const WR_SQUIRREL_ERROR = 5;
const WR_NEW_FW = 6;
const WR_BLINKUP = 9;
const WR_SW_RESTART = 10; //Planned addition in os 36, gotta get ready, yo

const DAY = 86400 //seconds

////////////////////////////////////////////////////////////////////////////////////////////////////
//this is where we lego together the sequence of events and the expected results after every event//
////////////////////////////////////////////////////////////////////////////////////////////////////

function createDeviceResults(lastSleep, wakeReason, storedReadings){
    return ({"lastSleep" : lastSleep, "wakeReason" : wakeReason, "storedReadings" : storedReadings});
}

function createSingleEvent(online, battery, wakeReason, connectSuccess, fakeTime, throwError, mute){
    return ({"online" : online, "battery" : battery, "wakeReason" : wakeReason, "connectSuccess" : connectSuccess, "fakeTime" : fakeTime, "mute" : mute, "throwError" : throwError});
}

// an "event" is a single main run for the device
// a single "device results" is some information from the device like how many stored readings it had
// a "sequence" is multiple "event/results" that form a narrative
//most time series will focus more or less around the time 0, as it is easy to calculate things relative to 0

jsonNull <- http.jsonencode([]);

//Sequence 0
//useful for clearing out the 'data last sent timestamp'
function exampleSequence(){

    testNameChangeArray[runMainSequenceArray.len()] <- "exampleSequence"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|      Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(        true,      3.31,    WR_TIMER,              true,              0,    false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);
    
    //Sequence
    //////////////////

    //1 (r2)
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
}

//Sequence 1
function connectedOrConnectingAndSendingData(){

    testNameChangeArray[runMainSequenceArray.len()] <- "connectedOrConnectingAndSendingData"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|  Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(        true,      3.31,    WR_TIMER,              true,          0,    false,     true/*mute*/);
    local eventB = createSingleEvent(        true,      3.31,    WR_TIMER,              true, (3600*6*1),    false,     true/*mute*/);
    local eventC = createSingleEvent(       false,      3.31,    WR_TIMER,              true, (3600*6*2),    false,     true/*mute*/);
    local eventD = createSingleEvent(       false,      3.31,    WR_TIMER,              true, (3600*6*3),    false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsC = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsD = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsE = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1 (r2)
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    
    //2 (r3)
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    
    //3 (r4)
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventC)
    
    //4 (r5)
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventD)
    
}

//Sequence 2
function notConnectedAndStoringReadingsThenSend(){

    testNameChangeArray[runMainSequenceArray.len()] <- "notConnectedAndStoringReadingsThenSend"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|  Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(        true,      3.31,    WR_TIMER,              true,           0,   false,     true/*mute*/);
    local eventB = createSingleEvent(       false,      3.31,    WR_TIMER,             false,  (3600*6*1),   false,     true/*mute*/);
    local eventC = createSingleEvent(       false,      3.31,    WR_TIMER,             false,  (3600*6*2),   false,     true/*mute*/);
    local eventD = createSingleEvent(       false,      3.31,    WR_TIMER,             false,  (3600*6*3),   false,     true/*mute*/);
    local eventE = createSingleEvent(       false,      3.31,    WR_TIMER,              true,  (3600*6*4),   false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               1);
    local deviceResultsC = createDeviceResults(    600,     WR_TIMER,               2);
    local deviceResultsD = createDeviceResults(    600,     WR_TIMER,               3);
    local deviceResultsE = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

    //5
    expectedResultsArray.append(deviceResultsE)
    runMainSequenceArray.append(eventE)
    
}

//Sequence 3
//some of these are unrealistic and could potentially be removed from testing
function differentWakeReasonsConnected(){

    testNameChangeArray[runMainSequenceArray.len()] <- "differentWakeReasonsConnected"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|  Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(        true,      3.31,     WR_BOOT,              true,          0,    false,     true/*mute*/);
    local eventB = createSingleEvent(        true,      3.31,    WR_TIMER,              true,          0,    false,     true/*mute*/);
    local eventC = createSingleEvent(        true,      3.31, WR_SW_RESET,              true,          0,    false,     true/*mute*/);
    local eventD = createSingleEvent(        true,      3.31,   WR_BUTTON,              true,          0,    false,     true/*mute*/);
    local eventE = createSingleEvent(        true,      3.31,WR_NEW_SQUIRREL,           true,          0,    false,     true/*mute*/);
    local eventF = createSingleEvent(        true,      3.31,WR_SQUIRREL_ERROR,         true,          0,    false,     true/*mute*/);
    local eventG = createSingleEvent(        true,      3.31,   WR_NEW_FW,              true,          0,    false,     true/*mute*/);
    local eventH = createSingleEvent(        true,      3.31,  WR_BLINKUP,              true,          0,    false,     true/*mute*/);
    //this wakereason not supported yet:
    //local eventI = createSingleEvent(        true,         3.31,    WR_SW_RESTART             true,           0,      false,     true/*mute*/);
    
    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,      WR_BOOT,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsC = createDeviceResults(    600,  WR_SW_RESET,               0);
    local deviceResultsD = createDeviceResults(    600,    WR_BUTTON,               0);
    local deviceResultsE = createDeviceResults(    600,WR_NEW_SQUIRREL,             0);
    local deviceResultsF = createDeviceResults(    600,WR_SQUIRREL_ERROR,           0);
    local deviceResultsG = createDeviceResults(    600,    WR_NEW_FW,               0);
    local deviceResultsH = createDeviceResults(    600,   WR_BLINKUP,               0);
    //this wakereason not supported yet:
    //local deviceResultsI = createDeviceResults(       600,        WR_SW_RESTART,         0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

    //5
    expectedResultsArray.append(deviceResultsE)
    runMainSequenceArray.append(eventE)

    //6
    expectedResultsArray.append(deviceResultsF)
    runMainSequenceArray.append(eventF)
    
    //7
    expectedResultsArray.append(deviceResultsG)
    runMainSequenceArray.append(eventG)
    
    //8
    expectedResultsArray.append(deviceResultsH)
    runMainSequenceArray.append(eventH)
    
    //9
    //NOT SUPPORTED YET:
    //expectedResultsArray.append(deviceResultsI)
    //runMainSequenceArray.append(eventI)
}


//Sequence 4
//some of these are unrealistic and could potentially be removed from testing
//others which are commented out are known failures
function differentWakeReasonsSuccessfulConnectionAttempt(){

    testNameChangeArray[runMainSequenceArray.len()] <- "differentWakeReasonsSuccessfulConnectionAttempt"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|  Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(       false,      3.31,     WR_BOOT,              true,    1 * DAY,     false,     true/*mute*/);
    local eventB = createSingleEvent(       false,      3.31,    WR_TIMER,              true,    2 * DAY,     false,     true/*mute*/);
    local eventC = createSingleEvent(       false,      3.31, WR_SW_RESET,              true,    3 * DAY,     false,     true/*mute*/);
    local eventD = createSingleEvent(       false,      3.31,   WR_BUTTON,              true,    4 * DAY,     false,     true/*mute*/);
    local eventE = createSingleEvent(       false,      3.31,WR_NEW_SQUIRREL,           true,    5 * DAY,     false,     true/*mute*/);
    local eventF = createSingleEvent(       false,      3.31,WR_SQUIRREL_ERROR,         true,    6 * DAY,     false,     true/*mute*/);
    local eventG = createSingleEvent(       false,      3.31,   WR_NEW_FW,              true,    7 * DAY,     false,     true/*mute*/);
    local eventH = createSingleEvent(       false,      3.31,  WR_BLINKUP,              true,    8 * DAY,     false,     true/*mute*/);
    //this wakereason not supported yet:
    //local eventI = createSingleEvent(        true,         3.31,    WR_SW_RESTART             true,           0,      false,     true/*mute*/);
    
    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,      WR_BOOT,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsC = createDeviceResults(    600,  WR_SW_RESET,               0);
    local deviceResultsD = createDeviceResults(    600,    WR_BUTTON,               0);
    local deviceResultsE = createDeviceResults(    600,WR_NEW_SQUIRREL,             0);
    local deviceResultsF = createDeviceResults(    600,WR_SQUIRREL_ERROR,           0);
    local deviceResultsG = createDeviceResults(    600,    WR_NEW_FW,               0);
    local deviceResultsH = createDeviceResults(    600,   WR_BLINKUP,               0);
    //this wakereason not supported yet:
    //local deviceResultsI = createDeviceResults(       600,        WR_SW_RESTART,         0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

    //5
    expectedResultsArray.append(deviceResultsE)
    runMainSequenceArray.append(eventE)

    //6
    expectedResultsArray.append(deviceResultsF)
    runMainSequenceArray.append(eventF)
    
    //7
    expectedResultsArray.append(deviceResultsG)
    runMainSequenceArray.append(eventG)
    
    //8
    expectedResultsArray.append(deviceResultsH)
    runMainSequenceArray.append(eventH)
    
    //9
    //NOT SUPPORTED YET:
    //expectedResultsArray.append(deviceResultsI)
    //runMainSequenceArray.append(eventI)
}


//Sequence 5
//some of these are unrealistic and could potentially be removed from testing
//others which are commented out are known failures
function differentWakeReasonsUnsuccessfulConnectionAttempt(){

    testNameChangeArray[runMainSequenceArray.len()] <- "differentWakeReasonsUnsuccessfulConnectionAttempt"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|  Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(       false,      3.31,     WR_BOOT,             false,    1 * DAY,    false,     true/*mute*/);
    local eventB = createSingleEvent(       false,      3.31,    WR_TIMER,             false,    2 * DAY,    false,     true/*mute*/);
    local eventC = createSingleEvent(       false,      3.31, WR_SW_RESET,             false,    3 * DAY,    false,     true/*mute*/);
    local eventD = createSingleEvent(       false,      3.31,   WR_BUTTON,             false,    4 * DAY,    false,     true/*mute*/);
    local eventE = createSingleEvent(       false,      3.31,WR_NEW_SQUIRREL,          false,    5 * DAY,    false,     true/*mute*/);
    local eventF = createSingleEvent(       false,      3.31,WR_SQUIRREL_ERROR,        false,    6 * DAY,    false,     true/*mute*/);
    local eventG = createSingleEvent(       false,      3.31,   WR_NEW_FW,             false,    7 * DAY,    false,     true/*mute*/);
    local eventH = createSingleEvent(       false,      3.31,  WR_BLINKUP,             false,    8 * DAY,    false,     true/*mute*/);
    //this wakereason not supported yet:
    //local eventI = createSingleEvent(        true,         3.31,    WR_SW_RESTART             true,           0,      false,     true/*mute*/);
    
    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,      WR_BOOT,               1);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               2);
    local deviceResultsC = createDeviceResults(    600,  WR_SW_RESET,               3);
    local deviceResultsD = createDeviceResults(    600,    WR_BUTTON,               4);
    local deviceResultsE = createDeviceResults(    600,WR_NEW_SQUIRREL,             5);
    local deviceResultsF = createDeviceResults(    600,WR_SQUIRREL_ERROR,           6);
    local deviceResultsG = createDeviceResults(    600,    WR_NEW_FW,               7);
    local deviceResultsH = createDeviceResults(    600,   WR_BLINKUP,               8);
    //this wakereason not supported yet:
    //local deviceResultsI = createDeviceResults(       600,        WR_SW_RESTART,         0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

    //5
    expectedResultsArray.append(deviceResultsE)
    runMainSequenceArray.append(eventE)

    //6
    expectedResultsArray.append(deviceResultsF)
    runMainSequenceArray.append(eventF)
    
    //7
    expectedResultsArray.append(deviceResultsG)
    runMainSequenceArray.append(eventG)
    
    //8
    expectedResultsArray.append(deviceResultsH)
    runMainSequenceArray.append(eventH)
    
    //9
    //NOT SUPPORTED YET:
    //expectedResultsArray.append(deviceResultsI)
    //runMainSequenceArray.append(eventI)
}

function throwMainErrorConnected(){

    testNameChangeArray[runMainSequenceArray.len()] <- "throwMainErrorConnected"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|  Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(        true,      3.31,    WR_TIMER,              true,          0,     true,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1 (r2)
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)

}

function throwMainErrorSuccessfulConnection(){

    testNameChangeArray[runMainSequenceArray.len()] <- "throwMainErrorSuccessfulConnection"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|  Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(       false,      3.31,    WR_TIMER,              true,          0,     true,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1 (r2)
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)

}

function throwMainErrorFailedConnection(){

    testNameChangeArray[runMainSequenceArray.len()] <- "throwMainErrorFailedConnection"

    //Events
    ///////////////////////////         Connected|   Battery| Wake Reason|    connectSuccess|  Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(       false,      3.31,    WR_TIMER,             false,          0,     true,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1 (r2)
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)

}

//these will need to be updated if they're ever changed on the device:

//how it will work one day:

//const HIGHEST_FREQUENCY = 300; //60 seconds * 5
const HIGH_FREQUENCY = 600;   //60 seconds * 10
//const MEDIUM_FREQUENCY= 1800;  //60 seconds * 30
//const LOW_FREQUENCY = 3600;    //60 seconds * 60
//const LOWER_FREQUENCY = 6000; //60 seconds * 100
//const LOWEST_FREQUENCY = 7200;//60 seconds * 240

//how it currently works:
const HIGHEST_FREQUENCY = 600; //== HIGH_FREQUENCY
const MEDIUM_FREQUENCY= 600;  //== HIGH_FREQUENCY
const LOW_FREQUENCY = 600;    //== HIGH_FREQUENCY
const LOWER_FREQUENCY = 600; //== HIGH_FREQUENCY
const LOWEST_FREQUENCY = 600;//== HIGH_FREQUENCY


const HIGHEST_BATTERY = 3.4;         //Volts
const HIGH_BATTERY = 3.35
const MEDIUM_BATTERY = 3.3;      //Volts
const LOW_BATTERY = 3.24;         //Volts
const LOWER_BATTERY = 3.195;        //Volts



function testSendFrequencyHighestBattery(){

    testNameChangeArray[runMainSequenceArray.len()] <- "testSendFrequencyHighestBattery"

    //Events
    ///////////////////////////         Connected|                  Battery|Wake Reason|   connectSuccess|                Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(        true,  HIGHEST_BATTERY + 0.001,   WR_TIMER,             true,                        0,    false,     true/*mute*/);
    local eventB = createSingleEvent(       false,  HIGHEST_BATTERY + 0.001,   WR_TIMER,             true,                        0,    false,     true/*mute*/);
    local eventC = createSingleEvent(       false,  HIGHEST_BATTERY + 0.001,   WR_TIMER,             true,    HIGHEST_FREQUENCY - 1,    false,     true/*mute*/);
    local eventD = createSingleEvent(       false,  HIGHEST_BATTERY + 0.001,   WR_TIMER,             true,    HIGHEST_FREQUENCY + 1,    false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               1);
    local deviceResultsC = createDeviceResults(    600,     WR_TIMER,               2);
    local deviceResultsD = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

}

function testSendFrequencyHighBattery(){

    testNameChangeArray[runMainSequenceArray.len()] <- "testSendFrequencyHighBattery"

    //Events
    ///////////////////////////         Connected|                  Battery|Wake Reason|   connectSuccess|                Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(         true,    HIGH_BATTERY + 0.001,   WR_TIMER,             true,                        0,    false,     true/*mute*/);
    local eventB = createSingleEvent(        false,    HIGH_BATTERY + 0.001,   WR_TIMER,             true,                        0,    false,     true/*mute*/);
    local eventC = createSingleEvent(        false,    HIGH_BATTERY + 0.001,   WR_TIMER,             true,       HIGH_FREQUENCY - 1,    false,     true/*mute*/);
    local eventD = createSingleEvent(        false,    HIGH_BATTERY + 0.001,   WR_TIMER,             true,       HIGH_FREQUENCY + 1,    false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               1);
    local deviceResultsC = createDeviceResults(    600,     WR_TIMER,               2);
    local deviceResultsD = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

}

function testSendFrequencyMediumBattery(){

    testNameChangeArray[runMainSequenceArray.len()] <- "testSendFrequencyMediumBattery"

    //Events
    ///////////////////////////         Connected|                  Battery|Wake Reason|   connectSuccess|                Fake Time|    Error|     Mute|
    local eventA = createSingleEvent(         true,  MEDIUM_BATTERY + 0.001,   WR_TIMER,             true,                        0,    false,     true/*mute*/);
    local eventB = createSingleEvent(        false,  MEDIUM_BATTERY + 0.001,   WR_TIMER,             true,                        0,    false,     true/*mute*/);
    local eventC = createSingleEvent(        false,  MEDIUM_BATTERY + 0.001,   WR_TIMER,             true,     MEDIUM_FREQUENCY - 1,    false,     true/*mute*/);
    local eventD = createSingleEvent(        false,  MEDIUM_BATTERY + 0.001,   WR_TIMER,             true,     MEDIUM_FREQUENCY + 1,    false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               1);
    local deviceResultsC = createDeviceResults(    600,     WR_TIMER,               2);
    local deviceResultsD = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

}

function testSendFrequencyLowBattery(){

    testNameChangeArray[runMainSequenceArray.len()] <- "testSendFrequencyLowBattery"

    //Events
    ///////////////////////////         Connected|                  Battery|Wake Reason|   connectSuccess|                Fake Time|      Error|     Mute|
    local eventA = createSingleEvent(         true,     LOW_BATTERY + 0.001,   WR_TIMER,             true,                        0,      false,     true/*mute*/);
    local eventB = createSingleEvent(        false,     LOW_BATTERY + 0.001,   WR_TIMER,             true,                        0,      false,     true/*mute*/);
    local eventC = createSingleEvent(        false,     LOW_BATTERY + 0.001,   WR_TIMER,             true,        LOW_FREQUENCY - 1,      false,     true/*mute*/);
    local eventD = createSingleEvent(        false,     LOW_BATTERY + 0.001,   WR_TIMER,             true,        LOW_FREQUENCY + 1,      false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,        WR_TIMER,                 0);
    local deviceResultsB = createDeviceResults(    600,        WR_TIMER,                 1);
    local deviceResultsC = createDeviceResults(    600,        WR_TIMER,                 2);
    local deviceResultsD = createDeviceResults(    600,        WR_TIMER,                 0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

}

function testSendFrequencyLowerBattery(){

    testNameChangeArray[runMainSequenceArray.len()] <- "testSendFrequencyLowerBattery"

    //Events
    ///////////////////////////         Connected|                  Battery|Wake Reason|   connectSuccess|                Fake Time|     Error|     Mute|
    local eventA = createSingleEvent(        true,    LOWER_BATTERY + 0.001,   WR_TIMER,             true,                         0,    false,     true/*mute*/);
    local eventB = createSingleEvent(       false,    LOWER_BATTERY + 0.001,   WR_TIMER,             true,                         0,    false,     true/*mute*/);
    local eventC = createSingleEvent(       false,    LOWER_BATTERY + 0.001,   WR_TIMER,             true,       LOWER_FREQUENCY - 1,    false,     true/*mute*/);
    local eventD = createSingleEvent(       false,    LOWER_BATTERY + 0.001,   WR_TIMER,             true,       LOWER_FREQUENCY + 1,    false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               1);
    local deviceResultsC = createDeviceResults(    600,     WR_TIMER,               2);
    local deviceResultsD = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

}

function testSendFrequencyLowestBattery(){

    testNameChangeArray[runMainSequenceArray.len()] <- "testSendFrequencyLowestBattery"

    //Events
    ///////////////////////////         Connected|                  Battery|Wake Reason|   connectSuccess|                Fake Time|     Error|     Mute|
    local eventA = createSingleEvent(        true,    LOWER_BATTERY - 0.001,   WR_TIMER,             true,                        0,     false,     true/*mute*/);
    local eventB = createSingleEvent(       false,    LOWER_BATTERY - 0.001,   WR_TIMER,             true,                        0,     false,     true/*mute*/);
    local eventC = createSingleEvent(       false,    LOWER_BATTERY - 0.001,   WR_TIMER,             true,     LOWEST_FREQUENCY - 1,     false,     true/*mute*/);
    local eventD = createSingleEvent(       false,    LOWER_BATTERY - 0.001,   WR_TIMER,             true,     LOWEST_FREQUENCY + 1,     false,     true/*mute*/);

    //Device Results 
    ////////////////////////////////////     lastSleep|   wakeReason|  storedReadings|
    local deviceResultsA = createDeviceResults(    600,     WR_TIMER,               0);
    local deviceResultsB = createDeviceResults(    600,     WR_TIMER,               1);
    local deviceResultsC = createDeviceResults(    600,     WR_TIMER,               2);
    local deviceResultsD = createDeviceResults(    600,     WR_TIMER,               0);

    //Sequence
    //////////////////

    //1
    expectedResultsArray.append(deviceResultsA)
    runMainSequenceArray.append(eventA)
    //2
    expectedResultsArray.append(deviceResultsB)
    runMainSequenceArray.append(eventB)
    //3
    expectedResultsArray.append(deviceResultsC)
    runMainSequenceArray.append(eventC)
    //4
    expectedResultsArray.append(deviceResultsD)
    runMainSequenceArray.append(eventD)

}


successes <- []
failures <- []
function logResults(a = "a" , b = "b"){
    server.log("\n\n\n\n\n\n\n\nDone running all tests (here are some results)")
    local errors = expectedResultsArray.len() - 1 - (successes.len() + failures.len())
    server.log("Successes: " + successes.len())
    server.log("Failures: " + failures.len())
    server.log("Errors: " + errors)
    for(local z = 0; z < failures.len(); z++){
        server.log("\n FAILURE #" + z)
        server.log(failures[z])
    }
    imp.wakeup(10,logResults)
}

////////////////
//Run the loop//
////////////////

runDelay <- 15.0;
function runMainLoop(){
    if(mainRunNumber in testNameChangeArray){
        testName = testNameChangeArray[mainRunNumber];
    }
    if(mainRunNumber < runMainSequenceArray.len()){
        local nextRunTable = runMainSequenceArray[mainRunNumber];
        server.log ("\n\nRUNNING MAIN SEQUENCE " + mainRunNumber + "/" + (runMainSequenceArray.len()-1) +  "\nrunnining with parameters:\n" + "\nconnected: " + nextRunTable.online  + "\nbattery: " + nextRunTable.battery)
        runMain(nextRunTable)
    } else {
        logResults();    
    }
}
server.log("delaying start, clear the console!");
imp.sleep(3);

function processDeviceResults(results){
    server.log("DEVICE RESULTS:\n" + http.jsonencode(results))
    local mainIndex = results.mainRun;
    local failureString = ""
    local lastSleep = results.lastSleep;
    if("lastSleep" in expectedResultsArray[mainIndex]){
        //equals to
        if(expectedResultsArray[mainIndex].lastSleep != results.lastSleep){
            server.log("FAIL LAST SLEEP ON MAIN RUN " + mainIndex)
            failureString = failureString + testName + " fail lastSleep in event " + mainIndex + ", expected: " + expectedResultsArray[mainIndex].lastSleep + ", actual: " + results.lastSleep + "\n"
        }
    }
    if(results.wakeReason != expectedResultsArray[mainIndex].wakeReason){
        server.log("FAIL WAKE REASON ON MAIN RUN " + mainIndex)
        failureString = failureString + testName + " fail wakeReason in event " + mainIndex + ", expected: " + expectedResultsArray[mainIndex].wakeReason + ", actual: " + results.wakeReason+ "\n"
    }
    if(results.storedReadings != expectedResultsArray[mainIndex].storedReadings){
        server.log("FAIL stored readings ON MAIN RUN " + mainIndex)
        failureString = failureString + testName + " fail storedReadings in event " + mainIndex + ", expected exactly: " + expectedResultsArray[mainIndex].storedReadings + ", actual: " + results.storedReadings+ "\n"
    }
    if(failureString.len()){
        server.log(failureString)
        failures.append(failureString)
    } else {
        server.log("\n\nEVENT " + mainIndex + " " + testName + " SUCCESS\n\n")
        successes.append(mainIndex)
    }
    imp.wakeup(1, runMainLoop);
}

device.on("deviceResults", processDeviceResults);


//MAKNIG THE EVENT LIST:
//(node that exampleSequence resets the 'data last sent timestamp' to 0 so it's useful for clearing out the last results)

exampleSequence();
connectedOrConnectingAndSendingData();
exampleSequence();
notConnectedAndStoringReadingsThenSend();
exampleSequence();
differentWakeReasonsConnected();
exampleSequence();
differentWakeReasonsSuccessfulConnectionAttempt();
exampleSequence();
differentWakeReasonsUnsuccessfulConnectionAttempt();
exampleSequence();
throwMainErrorConnected();
exampleSequence();
throwMainErrorSuccessfulConnection();
exampleSequence();
throwMainErrorFailedConnection();
exampleSequence();
testSendFrequencyHighestBattery();
testSendFrequencyHighBattery();
testSendFrequencyMediumBattery();
testSendFrequencyLowBattery();
testSendFrequencyLowerBattery();
testSendFrequencyLowestBattery();
//Start running the tests:
runMainLoop();

http.onrequest(logResults)

device.on("jsonLog", function (data)  {
    server.log("JSON LOG:")
    server.log(http.jsonencode(data))
});













