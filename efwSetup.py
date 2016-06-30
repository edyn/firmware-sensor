import sys
import subprocess
import getopt, sys
import os
from tempfile import mkstemp
from shutil import move
from os import remove, close
import os

##TODO: make this initialize the whole thing.



apiKey = sys.argv[1]

efwPath = os.path.dirname(os.path.abspath(__file__))
efwPath = efwPath + "/Scripts/efw.sh"

def copyfile(infile, outfile):
    shellCall = "cp -f " + infile + " " + outfile
    subprocess.call([shellCall], shell=True)

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

def changeEFWTargetPath():
    #changes the expected path for efw to point to efw_python.py
    currentPath = os.path.dirname(os.path.abspath(__file__))
    fwScriptsIndex = currentPath.find("/firmware-");
    currentPath = currentPath[0:fwScriptsIndex]    
    with open (efwPath, 'w') as efwFileOpen:
        efwFileOpen.write('Python '+ currentPath + '/firmware-$1/Scripts/efw_python.py "$*"')
    copyfile(efwPath, "/usr/local/bin")
#also blanks out whole imp config:
def changeEImpAPIKey():
    currentPath = os.path.dirname(os.path.abspath(__file__))
    impConfigPath = currentPath + "/.impconfig"
    with open (impConfigPath, 'w') as impFile:
        impFile.write("{\n");
        impFile.write('\t"apiKey": "' + apiKey + '",\n')
        impFile.write('\t"modelName": "",\n')
        impFile.write('\t"modelId": "",\n')
        impFile.write('\t"devices": [],\n')
        impFile.write('\t"deviceFile": "sensor.device.nut",\n')
        impFile.write('\t"agentFile": "sensor.agent.nut"\n')
        impFile.write('}')

if(len(sys.argv) > 1):
    changeEImpAPIKey()
    changeEFWTargetPath()
else:
    print "Include API key"
