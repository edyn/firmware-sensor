import os
mypath=os.path.dirname(os.path.abspath(__file__))
agentFile=mypath+"/valve.agent.nut"
agentTests=mypath+"/valve.agent.tests.nut"
agentConcat=mypath+"/valve.agent.unit.nut"

deviceFile=mypath+"/valve.device.nut"
deviceTests=mypath+"/valve.device.tests.nut"
deviceConcat=mypath+"/valve.device.unit.nut"
with open(agentFile, 'r') as fin:
    agentText=fin.read()
with open(agentTests, 'r') as fin:
    agentTests=fin.read()
#with open(agentConcat, 'w+') as fin:
#    agentTestsText=fin.read()
    
with open(deviceFile, 'r') as fin:
    deviceText=fin.read()
with open(deviceTests, 'r') as fin:
    deviceTests=fin.read()

errNumber = 0
errTable = ['a"','b"','c"','d"','e"','f"','g"','h"','i"']
currentfunc=""

wholeLine=""
wholeDeviceUnitFile=""
for letter in deviceText:
    wholeLine+=letter
    if(letter=="\n"):
        if(len(wholeLine)>6):
            if(wholeLine[0:8]=="function"):
                currentfunc = '"'+wholeLine[9:12]
                print "changing to" + currentfunc
                errNumber = 0
        if(wholeLine=="unitTesting <- false;\n"):
            print "foundit!"
            print wholeLine
            wholeDeviceUnitFile+="unitTesting <- true;\nthrowErrors <- 'z';\n"
        elif(len(wholeLine)>4):
            if(wholeLine[-5:]=="try{\n"):
                wholeDeviceUnitFile += wholeLine
                wholeDeviceUnitFile += ("if(throwErrors==" + currentfunc+errTable[errNumber]+"){server.log(THISTHROWSERRORS)};\n")
                errNumber += 1
            else:
                wholeDeviceUnitFile+=wholeLine
        else:
            wholeDeviceUnitFile+=wholeLine
        wholeLine=""
            

with open(deviceConcat, 'w+') as fin:
    fin.write(wholeDeviceUnitFile+deviceTests)
with open(agentConcat, 'w+') as fin:
    fin.write(agentText+agentTests)


