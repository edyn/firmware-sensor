if [$1 == "valve"]; then 
	Python /Users/dustinfranco/Edyn/firmware-valve/Scripts/efw_python.py "$*"
else [$1 == "sensor"]; then 
	Python /Users/dustinfranco/Edyn/firmware-sensor/Scripts/efw_python.py "$*"
	