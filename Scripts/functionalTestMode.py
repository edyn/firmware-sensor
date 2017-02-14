import os
import getopt, sys
import os
from tempfile import mkstemp
from shutil import move
from os import remove, close
mypath=os.path.dirname(os.path.abspath(__file__))
agentFile=mypath+"/valve.agent.nut"
agentTests=mypath+"/valve.agent.function.tests.nut"
agentConcat=mypath+"/valve.agent.function.nut"

deviceFile=mypath+"/valve.device.nut"
deviceTests=mypath+"/valve.device.function.tests.nut"
deviceConcat=mypath+"/valve.device.function.nut"

#with open(agentConcat, 'w+') as fin:
#    agentTestsText=fin.read()
    


def replace(file_path, pattern, subst):
    #Create temp file
    fh, abs_path = mkstemp()
    with open(abs_path,'w') as new_file:
        with open(file_path) as old_file:
            for line in old_file:
                new_file.write(line.replace(pattern, subst))
    close(fh)
    #Remove original file
    remove(file_path)
    #Move new file
    move(abs_path, file_path)



#Device File Editing
wholeLine=""
wholeDeviceUnitFile=""

#Simple Replace:
replace(deviceFile, "server.sleepFor", "mostRecentDeepSleepCall = ")
replace(deviceFile, "server.log(", "if(!mute)server.log(")
replace(deviceFile, "forwardPin.write(1);","")
replace(deviceFile, "controlPin.write(1);","")

replace(deviceFile, "unitTesting <- false;", "unitTesting <- true;\ncodeDebug <- false;\ninitialPhaseBool <- false;\n throwError <- false")
replace(deviceFile, "server.isconnected()", "fakeWifi")
replace(deviceFile, "dataTable.batteryVoltage <- ", "dataTable.batteryVoltage <- fakeBattery//")
replace(deviceFile, "dataTable.batteryMean <- nv.lastEMA;", "dataTable.batteryMean <- fakeBattery;")
replace(deviceFile, "const BLINKUP_TIMER", "const BLINKUP_TIMER = 0.1;//")
replace(deviceFile, "time()", "fakeTime")
replace(deviceFile, "local nextConnectionTime", "local nextConnectionTime =  120//")
replace(deviceFile, "server.connect(","server.disconnect();\nserver.connect(")
replace(deviceFile, "function firstXSecondsCheck(){", "function firstXSecondsCheck(){return initialPhaseBool;")
replace(deviceFile,'server.log("OS', '//')
replace(deviceFile,'server.log("main")', '{}\nif(throwError){THROWANERROR};')
replace(deviceFile, 'mostRecentDeepSleepCall = inputTime;', 'mostRecentDeepSleepCall = inputTime;\nsendResults();')

replace(deviceFile, "function correctReadingTimestamps(readings){", "function correctReadingTimestamps(readings){return readings")

#Agent File Editing
replace(agentFile,'server.log("OS', '//')
replace(agentFile,'httpPut(updateWateringsURL', 'wateringToSend=http.jsondecode(wateringToSend)\nwateringToSend.uuid <- singleWatering.uuid;\nlastWateringsFromDevice.append(wateringToSend)//')
#Simple Replace:
replace(agentFile, '#require "Loggly.class.nut:1.1.0"','#require "Loggly.class.nut:1.1.0"\ncodeDebug <- false;\ntestDebug <- true;')
replace(agentFile, 'local responseBody = httpGet(apiScheduleURL, "", headers)', 'local responseBody = scheduleFromBackend')
replace(agentFile, "unitTesting <- 0;", 'unitTesting <- 1;')
replace(agentTests, "server.log", "if(testDebug)server.log")

insertAtTopOfDevice = "fakeTime <- 0;\nmute <- false;\n"

with open(agentFile, 'r') as fin:
    agentText=fin.read()
with open(agentTests, 'r') as fin:
    agentTests=fin.read()
with open(deviceFile, 'r') as fin:
    deviceText=fin.read()
with open(deviceTests, 'r') as fin:
    deviceTests=fin.read()


            

with open(deviceConcat, 'w+') as fin:
    fin.write(insertAtTopOfDevice + deviceText + "\n" + deviceTests)
with open(agentConcat, 'w+') as fin:
    fin.write(agentText + "\n" + agentTests)


