#!/bin/bash
#                   by Chris Mavrakis (spamable - at - cmavrakis.com)
#
#
# This script assumes that you do not like VMWare services running on your laptop
# all the time, so you disabled them on boot, and are only starting them when
# you need to run VMWare. This script automates the starting/stopping procedure.
#
# Installation:
#     To be able to start/stop services as a normal user without being asked
#     for a password, run:
#         sudo visudo
#     and append these lines, substituting myusername with your username:
#         %myusername ALL=(root) NOPASSWD:/usr/bin/service vmamqpd *
#         %myusername ALL=(root) NOPASSWD:/usr/bin/service vmware *
#         %myusername ALL=(root) NOPASSWD:/usr/bin/service vmware-workstation-server *
#         %myusername ALL=(root) NOPASSWD:/usr/bin/service vmware-USBArbitrator *
#     and of course save :P
# 
# Usage:
#     To start VMWare services and VMWare Workstation run:
#         my-vmware start
#     To stop VMWare services and VMWare Workstation run:
#         my-vmware stop


if [[ $1 == 'start' ]]; then
        # Start all the vmware services, one by one, in the right order
        echo "*** First, we start the services..."
        sudo service vmamqpd start | grep failed
        sudo service vmware-USBArbitrator start | grep failed
        echo "*** Starting the server (takes some time)..."
        sudo service vmware-workstation-server start | grep failed
        echo "*** Almost done, starting vmware..."
        sudo service vmware start | grep failed

        # Run the dirty workaround, for the "keys stuck or unresponsive" bug
        echo "*** Now starting keybord fix..."
        watch -n 0.5 "setxkbmap" > /dev/null &
        # Get process's pid and save to file
        pid=$!
        echo $pid > /tmp/myvm.pid
        echo "*** Watcpid saved:" $pid

        # Finally start the GUI
        echo "*** Finally, VMWare Workstation is starting. Run 'vmware stop' to stop services."
        vmware &> /dev/null &

elif [[ $1 == 'stop' ]]; then
        # Stop all vmware services in the right order
        echo "*** Ok, stopping VMWare..."
        sudo service vmware stop | grep failed
        sudo service vmware-workstation-server stop | grep failed
        sudo service vmware-USBArbitrator stop | grep failed
        sudo service vmamqpd stop | grep failed

        # Also kill the workaround process
        # Get pid from file and kill the watch process
        pid=`cat /tmp/myvm.pid 2>/dev/null`
        echo "*** Killing watch with pid" $pid
        kill $pid 2>/dev/null

        echo "*** All done, exiting"
else
        echo "*** No valid options given. Please re-run with either 'start' or 'stop'."
fi
