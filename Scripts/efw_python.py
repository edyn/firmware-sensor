import sys
import os
import subprocess
import json
import httplib
import urllib
import base64


ScriptsPath = os.path.dirname(os.path.realpath(__file__))
WorkingPath = ScriptsPath[0:-(len("/Scripts"))]
ArgumentList = sys.argv[1].split();


#default inputs:
versionNumber = "0.0.1"
staging = "feature"
device = ""
debugModes = [];


helpText = [\
"\n\nRequired Arguments\n",
"First Argument must be 'valve' or 'sensor' (or 'v'/'s')",
"NOTE: there is no dash for this argument",
"\n\n",
"Optional Arguments",
"\n-v, 'version'",
"\t the argument following -v needs to be version number, example use: -v 0.0.2",
"\t default without -v argument is version number 0.0.1",
"\n-m, 'master' / -d, 'develop'",
"\t this pulls the edyn master or edyn develop branches from github and uses them",
"\t -m overrides -d",
"\t default without this argument is 'feature', which uses the code in the current branch",
"\t still uses 'feature' level unit tests",
"\n-dm,'debug memory'", 
"\t prints the amount of available memory at the end of each function",
"\n-do, 'debug offline'",
"\t prints all server logs over UART, only configured for valve right now",
"\n-ut, unit testing",
"\t Unit testing mode, uses the unit tests currently in firmware-device/firmware_device_versionNumber/",
"\n\n"
]

#could switch shell calls to imports in the future.
#right now they work perfectly so I don't want to mess with them"

def copyfile(infile, outfile):
	shellCall = "cp -f " + infile + " " + outfile
	subprocess.call([shellCall], shell=True)

firstSnapShot = []

def snapShotDir():
	snapShot = []
	for path, subdirs, files in os.walk(WorkingPath):
	    for name in files:
	        snapShot.append(os.path.join(path, name))
	return snapShot

firstSnapShot = snapShotDir()

def cleanDir(maxFilesToDelete = 50):
	print "CLEANING DIRECTORY"
	secondSnapShot = []
	filesToDelete = 0
	workingPathLen = len(WorkingPath + "/LastPush/")
	#clear out last push:
	for eachFile in firstSnapShot:
		if (eachFile.find("LastPush") > 0):
			if(eachFile.find("gitignore") < 0):
				if(eachFile.find("CurrentFFW") < 0):
					os.remove(eachFile)
	#take a second snapshot
	secondSnapShot = snapShotDir()



	#how many files do we have to delete:
	for eachFile in os.listdir(WorkingPath):
		if ((WorkingPath + "/" + eachFile not in firstSnapShot) and eachFile[0] != "." and (eachFile.endswith(".nut") or eachFile.endswith(".py"))):
			copyfile(WorkingPath + "/" + eachFile, WorkingPath+"/LastPush/"+eachFile)
			
			filesToDelete += 1
	if(filesToDelete > maxFilesToDelete):
		print "more than " + maxFilesToDelete + " files queued to delete, not deleting"
	else:
		for eachFile in secondSnapShot:
			if(eachFile.find("LastPush") < 0):
				if(eachFile not in firstSnapShot):
					if(eachFile.find("CurrentFFW") < 0):
						os.remove(eachFile)
					

def pushWorkingPathToEimp():
	shellCall = WorkingPath + "/Scripts/pushWorkingPathToEimp.sh" + " " + WorkingPath
	subprocess.call([shellCall], shell=True)

def getImpAPIKey():
	tempApiStr = ""
	with open(WorkingPath + "/.impconfig",'r') as configFile:
		for line in configFile:
			substrIndex = line.find("apiKey")
			if(substrIndex > 0):
				tempApiStr = line[substrIndex+10:-3]
				print tempApiStr
	apiKey = base64.b64encode(tempApiStr)
	return apiKey

def getImpModelID(modelName, apiKey):
	try:
		print "trying to get model ID for model named " + modelName
		headers = {"Authorization":"Basic " + apiKey}
		params = urllib.urlencode({"name":modelName})
		connection = httplib.HTTPSConnection('build.electricimp.com')
		connection.connect()
		connection.request('GET', '/v4/models?' + params, '', headers)
		results = json.loads(connection.getresponse().read())
		modelID = results["models"][0]['id']
		return modelID
	except: 
		raise "error getting model ID, efw_python probably constructed a bad model name, or imp api key is wrong.\nModel name attempted:" + modelName

def configureImp(modelName, modelDeviceFile, modelAgentFile):
	ImpApiKey = getImpAPIKey()
	modelId = getImpModelID(modelName, ImpApiKey)
	ImpApiKey = base64.b64decode(ImpApiKey)
	with open(WorkingPath + "/.impconfig",'w+') as configFile:
		configFile.write("{\n")
		configFile.write('\t"apiKey": "' + ImpApiKey + '",\n')
		configFile.write('\t"modelName": "' + modelName + '",\n')
		configFile.write('\t"modelId": "' + modelId + '",\n')
		#TODO: we could make devices work properly but for now there's no real benefit
		configFile.write('\t"devices": [],\n')
		configFile.write('\t"deviceFile": "' + modelDeviceFile + '",\n')
		configFile.write('\t"agentFile": "' + modelAgentFile + '"\n')
		configFile.write("}")

def switchStaging(stageType):
	print "call switchstaging with stagetype argument"
	copyfile(WorkingPath+"/Scripts/switchStaging.py" , WorkingPath+"/switchStaging.py")
	shellCall = "Python " + WorkingPath + "/switchStaging.py " + staging
	subprocess.call([shellCall], shell = True)

def offlineDebugMode():
	if(device == "valve"):
		copyfile(WorkingPath+"/Scripts/offlineDebugCreation" + device + ".py", WorkingPath+"/offlineDebugCreation" + device + ".py")
		shellCall = "Python " + WorkingPath+"/offlineDebugCreation" + device + ".py" 
		subprocess.call([shellCall], shell = True)
	print "offlineDebugMode"

def memoryDebugMode():
	copyfile(WorkingPath+"/Scripts/LogMemory.py", WorkingPath+"/LogMemory.py")
	shellCall = "Python " + WorkingPath + "/LogMemory.py" 
	subprocess.call([shellCall], shell = True)
	print "memoryDebugmode"

def lightningDebugMode():
	copyfile(WorkingPath+"/Scripts/LightningMode.py", WorkingPath+"/LightningMode.py")
	shellCall = "Python " + WorkingPath + "/LightningMode.py" 
	subprocess.call([shellCall], shell = True)
	print "LightningMode"

def setBlinkupTimerToOne():
	copyfile(WorkingPath+"/Scripts/blinkupTimerOne.py", WorkingPath+"/blinkupTimerOne.py")
	shellCall = "Python " + WorkingPath + "/blinkupTimerOne.py" 
	subprocess.call([shellCall], shell = True)
	print "Blinkup timer set to one"

def unitTestMode():
	print "IMPORTANT: Unit tests will run on whatever unit tests are in product_version_prod regardless of what files you pull" 
	copyfile(WorkingPath+"/"+device+"_"+versionNumber+"_Prod/"+device+".agent.tests.nut", WorkingPath+"/" +device+".agent.tests.nut")
	copyfile(WorkingPath+"/"+device+"_"+versionNumber+"_Prod/"+device+".device.tests.nut", WorkingPath+"/"+device+".device.tests.nut")
	copyfile(WorkingPath+"/Scripts/UnitTestCreation.py", WorkingPath+"/UnitTestCreation.py")
	shellCall = "Python " + WorkingPath + "/UnitTestCreation.py" 
	subprocess.call([shellCall], shell = True)
	#configure imp

def functionalTestMode():
	print "running in functional test mode"
	copyfile(WorkingPath+"/"+device+"_"+versionNumber+"_Prod/"+device+".agent.function.tests.nut", WorkingPath+"/" +device+".agent.function.tests.nut")
	copyfile(WorkingPath+"/"+device+"_"+versionNumber+"_Prod/"+device+".device.function.tests.nut", WorkingPath+"/"+device+".device.function.tests.nut")
	copyfile(WorkingPath+"/Scripts/functionalTestMode.py", WorkingPath+"/functionalTestMode.py")
	shellCall = "Python " + WorkingPath + "/functionalTestMode.py" 
	subprocess.call([shellCall], shell = True)
	
	

def getMaster():
	shellCall = ScriptsPath + "/getMaster.sh" + " " + WorkingPath + " " + device + " " + versionNumber
	print "calling script "+ shellCall
	subprocess.call([shellCall], shell = True)
	staging = "Production"

def getDevelop():
	shellCall = ScriptsPath + "/getDevelop.sh" + " " + WorkingPath + " " + device + " " + versionNumber
	print "calling script "+ shellCall
	subprocess.call([shellCall], shell = True)
	staging = "Develop"

def getFeature():
	shellCall = ScriptsPath + "/getFeature.sh" + " " + WorkingPath + " " + device + " " + versionNumber
	print "calling script "+ shellCall
	subprocess.call([shellCall], shell = True)
	staging = "Feature"

def makeFFW(ArgumentList):
	copyfile(WorkingPath+"/"+device+"_"+versionNumber+"_Prod/Valve_0.0.1_FFW/"+device+".agent.FFW.nut", WorkingPath+"/" +device+".agent.FFW.nut")
	copyfile(WorkingPath+"/"+device+"_"+versionNumber+"_Prod/Valve_0.0.1_FFW/"+device+".device.FFW.nut", WorkingPath+"/"+device+".device.FFW.nut")
	copyfile(WorkingPath+"/Scripts/FFWCreation.py", WorkingPath+"/FFWCreation.py")
	shellCall = "Python " + WorkingPath + "/FFWCreation.py" 
	subprocess.call([shellCall], shell = True)
	staging = "FFW"

try:
	#Help overrides everything else
	if("help" in ArgumentList):
		for line in helpText:
			print line
	else: 
		#first argument is valve or sensor
		if(ArgumentList[0].lower()[0] == "v"):
			device = "valve"
		elif(ArgumentList[0].lower()[0] == "s"):
			device = "sensor"
			print "this doesn't work with sensor yet, come back in the fuuuuutuuuure"
		else:
			print "First argument needs to specify 'sensor' or 'valve'"
			assert(device == "valve" or device == "sensor")
		################
		#Version Number#
		################
		if("-v" in ArgumentList):
			vIndex = ArgumentList.index("-v")
			versionNumber = ArgumentList[vIndex + 1]
			print "Using Version Number " + versionNumber
		else:
			print "Using Default Version Number: " + versionNumber

		###################
		#Staging selection#
	    ###################

		#Staging, master overrides develop
		if("-m" in ArgumentList):
			staging = "production"
			if("-d" in ArgumentList):
				print "WARNING: Both -d and -m arguments, ignoring -d"
			print "Working with Edyn master branch"
			getMaster()
		#Staging develop
		elif("-d" in ArgumentList):
			staging = "develop"
			getDevelop()
			print "Working with Edyn develop branch"
		#Staging Feature
		else:
			print "Working with feature code in " + WorkingPath
			getFeature()
		#############
		#Debug Modes#
		#############

		#Debug Memory
		if("-dm" in ArgumentList):
			memoryDebugMode()
			staging = staging + "_Debug_Memory"
		#Debug Offline Mode
		if("-do" in ArgumentList):
			offlineDebugMode()
			staging = staging + "_Debug_Offline"
		#Debug Lightning Mode
		if("-lm" in ArgumentList):
			lightningDebugMode()
			staging = staging + "_Lightning"

		if("-bto" in ArgumentList):
			setBlinkupTimerToOne();
		############
		#Unit Tests#
		############

		if("-ut" in ArgumentList):
			unitTestMode()
			staging = staging + "_Unit_Tests"

		###############
		#whatever test#
		###############
		if("-t" in ArgumentList):
			functionalTestMode()
			staging = staging + "_functional_test"

		################
		#Switch Staging#
		################
		#name is kind of a misnomer
		switchStaging(staging);

		#####################
		#imp config and push#
		#####################

		deviceFile = device + ".device."
		agentFile = device + ".agent."
		if("-ut" in ArgumentList):
			deviceFile += "unit."
			agentFile += "unit."

		if("-t" in ArgumentList):
			deviceFile += "function."
			agentFile += "function."
		deviceFile += "nut"
		agentFile += "nut"

		#capitalize the first letter of device:
		device = device[0].upper() + device[1:]
		modelName = device + "_" + versionNumber

		if ( "-forceDevelop" in ArgumentList):
			modelName += "_Prod"
		elif("-ut" in ArgumentList):
			modelName += "_Unit_Testing"
		elif("-dm" in ArgumentList or "-do" in ArgumentList or "-lm" in ArgumentList or "-t" in ArgumentList):
			modelName += "_Debug_Model"
		elif("-d" in ArgumentList or "-m" in ArgumentList):
			modelName += "_Prod"
		else:
			modelName += "_Feature"

		##################
		#Factory Firmware#
		##################

		if("-ffw" in ArgumentList):
			#can't push FFW directly to imp because fuck me, right?
			makeFFW(ArgumentList);
		else:
			print "Pushing to imp"
			configureImp(modelName, deviceFile, agentFile)
			print "configuration complete"
			pushWorkingPathToEimp()
		cleanDir()
except: 
	print("Unexpected error:", sys.exc_info()[0])
	print "FATAL ERROR IN efw_python.py, cleaning directory"
	cleanDir()

