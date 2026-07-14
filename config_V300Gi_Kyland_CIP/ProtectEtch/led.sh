 #!/bin/bash

 ##############################################################################
 # Copyright (C) 2008 by Ma ping
 #
 # File: led.sh
 #
 # Date: 2008-11-01
 #
 # Author: Ma ping, <csmaping@126.com>
 #
 # Version: 0.1
 #
 # Descriptor:
 #   start led
 #
 # Modified:
 #
 ##############################################################################
source /etc/profile

path=$(dirname $(readlink -f $0))
cd $path
cd ../

executable_name=$(pwd)/bin
echo $executable_name
executable_pid=$(pgrep -f $executable_name)
echo $executable_pid

for pid in $executable_pid
do
        kill -9 $pid
done

sleep 2

$(pwd)/bin/NMCTool  $path

read -p "####Software has been exited, Press <Enter> to exit the terminal!!!"

