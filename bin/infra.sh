#!/bin/bash

#apt-get purge -y -q byobu pastebinit linux-headers-generic snapd

#apt-mark hold linux-image-generic

echo "RESUME=none" > /etc/initramfs-tools/conf.d/noresume.conf

#apt-get purge -y -q cryptsetup-initramfs libplymouth* libntfs-*

#apt-get update

#apt-get install -y -qq --no-install-recommends joe

#apt-get purge -y -q secureboot-db libpackagekit* usbmuxd
