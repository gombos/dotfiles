#!/bin/bash

echo "RESUME=none" > /etc/initramfs-tools/conf.d/noresume.conf
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

adduser --disabled-password --gecos "" usr && usermod -aG adm,sudo,netdev admin

#apt-get purge -y -q byobu pastebinit linux-headers-generic snapd secureboot-db libpackagekit* libplist* rsyslog

#apt-mark hold linux-image-generic linux-image-amd64

#apt-get purge -y -q cryptsetup-initramfs libplymouth* libntfs-*

apt-get update

apt-get install -y -qq --no-install-recommends micro git

runuser -u usr -- git clone https://github.com/gombos/dotfiles.git ~/.dotfiles
