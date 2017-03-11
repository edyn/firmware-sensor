echo switching to $1/Scripts
echo $@
cd $1/Scripts
git clone "https://github.com/edyn/firmware-"$2
cd $1/Scripts/firmware-$2


git checkout master
#TODO: check if this repo is cloned here and delete it if it is


#Confusing lines of code:
#they copy the agent files from the cloned git repo into the directory where they will be pushed from
cp $1/Scripts/firmware-$2/$2_$3_Prod/$2.agent.nut $1
cp $1/Scripts/firmware-$2/$2_$3_Prod/$2.device.nut $1
#Example of what the above line looks like:
#$1 = ~/edyn/firmware-valve
#$2 = valve
#$3 = 0.0.1
#evaluate to:
#cp ~/edyn/firmware-valve/Scripts/firmware-valve/valve_0.0.1_Prod/valve.agent.nut ~/edyn/firmware-valve/
rm -rf $1/Scripts/firmware-$2
#Probably want to uncomment this later:
#rm -r $1/Scripts/firmware-$2
