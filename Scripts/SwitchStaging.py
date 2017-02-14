import getopt, sys
import os
from tempfile import mkstemp
from shutil import move
from os import remove, close
import os

mypath=os.path.dirname(os.path.abspath(__file__))
agentFile=mypath+"/valve.agent.nut"
args = sys.argv;

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

def switchChoice():
    o = args[1]
    replace(agentFile,'logTable.env <- "Develop";','logTable.env <- "' + o + '";')
    replace(agentFile,'logTable.env <- "Feature";','logTable.env <- "' + o + '";')
    replace(agentFile,'logTable.env <- "Production";','logTable.env <- "' + o + '";')


    # ...
switchChoice()