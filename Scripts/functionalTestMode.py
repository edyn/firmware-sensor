#SENSOR
import os
import getopt, sys
import os
from tempfile import mkstemp
from shutil import move
from os import remove, close
mypath=os.path.dirname(os.path.abspath(__file__))
agentFile=mypath+"/sensor.agent.nut"
agentTests=mypath+"/sensor.agent.function.tests.nut"
agentConcat=mypath+"/sensor.agent.function.nut"

deviceFile=mypath+"/sensor.device.nut"
deviceTests=mypath+"/sensor.device.function.tests.nut"
deviceConcat=mypath+"/sensor.device.function.nut"

#with open(agentConcat, 'w+') as fin:
#    agentTestsText=fin.read()
 
print "\n     ***FUNCTIONAL TESTS***\n"   


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
replace(deviceFile, "server.sleepfor(inputTime)", 'mostRecentDeepSleepCall = inputTime;\nsendResults()');
replace(deviceFile, "server.log(", "if(!mute)server.log(")
replace(deviceFile, "WDTimer<-imp.wakeup(", "//WDTimer<-imp.wakeup(");
replace(deviceFile, "mainWithSafety();//Run Main", "//mainWithSafety();//Run Main")
replace(deviceFile, "testing <- false;", "testing <- true;\ncodeDebug <- false;\ninitialPhaseBool <- false;\n throwError <- false")
replace(deviceFile, "server.isconnected()", "fakeWifi")

#todo: need to add fake battery value
#todo: can i fake a 'not connected but then succeeds in connecting' kind of thing?

#todo: this probably has a different name
replace(deviceFile, "const blinkupTime", "const blinkupTime = 0.1;//")
#this should work without changing it:
replace(deviceFile, "time()", "fakeTime")
#lol, the sensor should change to fit this, but we'll have to make due for now
replace(deviceFile, "local nextConnectionTime", "local nextConnectionTime =  120//")
#hmm this needs some further thought on the valve as well:
replace(deviceFile, "server.connect(","server.disconnect();\nserver.connect(")

#I guess we might add this to the sensor:
replace(deviceFile,'server.log("main")', '{}\nif(throwError){THROWANERROR};')


#Agent File Editing
replace(agentFile,'httpPut(updateWateringsURL', 'wateringToSend=http.jsondecode(wateringToSend)\nwateringToSend.uuid <- singleWatering.uuid;\nlastWateringsFromDevice.append(wateringToSend)//')
#Simple Replace:
replace(agentFile, '#require "Loggly.class.nut:1.1.0"','#require "Loggly.class.nut:1.1.0"\ncodeDebug <- false;\ntestDebug <- true;')
replace(agentFile, "testing <- 0;", 'testing <- 1;')
replace(agentTests, "server.log", "if(testDebug)server.log")

insertAtTopOfDevice = "fakeTime <- 0;\nmute <- false;\nfakeWifi <- true;\nmostRecentDeepSleepCall <- -1\nwakeReason <- -1\nthrowError <- false\n"

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

print "\nFUNCTIONAL TEST SETUP COMPLETE\n"
