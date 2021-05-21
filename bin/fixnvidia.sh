#!/bin/sh

# Remove nvidia buggy udev rules. This at least stops the infinite loop
# thats failing at boot

sudo rm /lib/udev/rules.d/71-nvidia.rules
sudo service systemd-udevd restart
sleep 1

sudo service nvidia-persistenced stop
sudo rm /var/run/nvidia-persistenced/*

# Stop X
sudo service lxdm stop
sleep 5

# Unbinding vtconsole
sudo sh -c "sudo echo 0 > /sys/class/vtconsole/vtcon0/bind"
sudo sh -c "sudo echo 0 > /sys/class/vtconsole/vtcon1/bind"

sudo rmmod nouveau
sleep 5

sudo modprobe nvidia
sudo modprobe nvidia_uvm
sudo modprobe nvidia_drm

#lsmod | grep nvidia

sudo service nvidia-persistenced start

sudo service lxdm start

# journalctl -b -f
