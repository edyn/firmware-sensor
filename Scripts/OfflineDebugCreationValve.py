import os
mypath=os.path.dirname(os.path.abspath(__file__))

deviceFile=mypath+"/valve.device.nut"

    
with open(deviceFile, 'r') as fin:
    deviceText=fin.read()


wholeLine=""
wholeDeviceUnitFile=""
wholeDeviceUnitFile+= 'newLine<-"\\n\\r"\n';
wholeDeviceUnitFile+="offlineLog <-   hardware.uart1289;\n"
wholeDeviceUnitFile+="offlineLog.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);\n"
wholeDeviceUnitFile+="function newLog(message){\n"
wholeDeviceUnitFile+="    try{\n"
wholeDeviceUnitFile+="   server.log(message.tostring())\n"
wholeDeviceUnitFile+="    imp.sleep(0.1)\n"
wholeDeviceUnitFile+="    offlineLog.write(message.tostring())\n"
wholeDeviceUnitFile+="    offlineLog.write(newLine)\n"
wholeDeviceUnitFile+="    imp.sleep(0.1)\n"
wholeDeviceUnitFile+="    } catch(error){\n"
wholeDeviceUnitFile+="          server.log(error)\n"
wholeDeviceUnitFile+="    imp.sleep(0.1)\n"
wholeDeviceUnitFile+="    offlineLog.write(error)\n"
wholeDeviceUnitFile+="    offlineLog.write(newLine)\n"
wholeDeviceUnitFile+="    imp.sleep(0.1)}}\n" 



for letter in deviceText:
    wholeLine+=letter
    if(letter=="\n"):
        #if there 


        wholeLine=wholeLine.replace("forwardPin.configure(DIGITAL_OUT);","//forwardPin.configure(DIGITAL_OUT);")
        wholeDeviceUnitFile+=wholeLine.replace("server.log","newLog")
        wholeLine=""
            

with open(deviceFile, 'w+') as fin:
    fin.write(wholeDeviceUnitFile)


