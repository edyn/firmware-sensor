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

wholeLine=""
wholeDeviceUnitFile=""
for letter in deviceText:
    wholeLine+=letter
    if(letter=="\n"):
        if(wholeLine=="unitTesting <- false;\n"):
            print "foundit!"
            print wholeLine
            wholeDeviceUnitFile+="unitTesting <- true;\n"
        else:
            wholeDeviceUnitFile+=wholeLine
        wholeLine=""
            

with open(deviceConcat, 'w+') as fin:
    fin.write(wholeDeviceUnitFile+deviceTests)
with open(agentConcat, 'w+') as fin:
    fin.write(agentText+agentTests)

    