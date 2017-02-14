import os
import getopt, sys
import os
from tempfile import mkstemp
from shutil import move
from os import remove, close
mypath=os.path.dirname(os.path.abspath(__file__))
agentFile=mypath+"/valve.agent.nut"
agentTests=mypath+"/valve.agent.tests.nut"
agentConcat=mypath+"/valve.agent.unit.nut"

deviceFile=mypath+"/valve.device.nut"
deviceTests=mypath+"/valve.device.tests.nut"
deviceConcat=mypath+"/valve.device.unit.nut"

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

errNumber = 0
errTable = ['a"','b"','c"','d"','e"','f"','g"','h"','i"']
currentfunc='"'


#Device File Editing
wholeLine=""
wholeDeviceUnitFile=""

#Simple Replace:
replace(deviceFile, "server.sleepFor", "mostRecentDeepSleepCall = ")
replace(deviceFile, "forwardPin.write(1);","")
replace(deviceFile, "controlPin.write(1);","")
replace(deviceFile, "unitTesting <- false;", "unitTesting <- true;\nthrowErrors <- 'z';\ncodeDebug <- false;\ntestDebug <- true;")
replace(deviceFile, "server.log", "if(codeDebug)server.log")
replace(deviceTests, "server.log", "if(testDebug)server.log")
replace(deviceFile, "const FIRST_X_SECONDS_TIMER =","FIRST_X_SECONDS_TIMER <-")

#Complex Insertions:
with open(deviceFile, 'r') as fin:
    deviceText=fin.read()
with open(deviceTests, 'r') as fin:
    deviceTests=fin.read()
for letter in deviceText:
    wholeLine+=letter
    if(letter=="\n"):
        if(len(wholeLine)>6):
            if(wholeLine[0:8]=="function"):
                currentfunc = '"'+wholeLine[9:12]
                print wholeLine[0:-2] + "changing to" + currentfunc
                errNumber = 0
        if(len(wholeLine)>4):
            if(wholeLine[-5:]=="try{\n" or wholeLine[-6:]=="try {\n"):
                wholeDeviceUnitFile += wholeLine
                print("found a try")
                wholeDeviceUnitFile += ("if(throwErrors==" + currentfunc.lower()+errTable[errNumber]+"){server.log(THISTHROWSERRORS)};\n")
                errNumber += 1
            else:
                wholeDeviceUnitFile+=wholeLine
        else:
            wholeDeviceUnitFile+=wholeLine
        wholeLine=""


#Agent File Editing

#Simple Replace:
replace(agentFile, '#require "Loggly.class.nut:1.0.1"','#require "Loggly.class.nut:1.0.1"\ncodeDebug <- false;\ntestDebug <- true;')
replace(agentFile, "server.log", "if(codeDebug)server.log")
replace(agentTests, "server.log", "if(testDebug)server.log")
replace(agentFile,"addLogglyDefaults(logTable){","addLogglyDefaults(logTable){\nlastLoggly = logTable;\n")

with open(agentFile, 'r') as fin:
    agentText=fin.read()
with open(agentTests, 'r') as fin:
    agentTests=fin.read()


            

with open(deviceConcat, 'w+') as fin:
    fin.write(wholeDeviceUnitFile+deviceTests)
with open(agentConcat, 'w+') as fin:
    fin.write(agentText+agentTests)


