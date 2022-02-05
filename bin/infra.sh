#!/bin/bash

echo "RESUME=none" > /etc/initramfs-tools/conf.d/noresume.conf
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config

adduser --disabled-password --gecos "" usr && usermod -aG adm,sudo,netdev usr
mkdir -p /home/usr/.ssh/
mv /root/.ssh/authorized_keys /home/usr/.ssh/
chmod 400 /home/usr/.ssh/authorized_keys
chown -R usr:usr /home/usr/.ssh/

#apt-get purge -y -q byobu pastebinit linux-headers-generic snapd secureboot-db libpackagekit* libplist* rsyslog

#apt-mark hold linux-image-generic linux-image-amd64

#apt-get purge -y -q cryptsetup-initramfs libplymouth* libntfs-*

apt-get update

apt-get install -y -qq --no-install-recommends micro git

rm -rf /home/usr/.*

runuser -u usr -- git clone https://github.com/gombos/dotfiles.git /home/usr/.dotfiles

#todo - disable root user as much as possible
