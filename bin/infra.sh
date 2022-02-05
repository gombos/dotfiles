#!/bin/bash

echo "RESUME=none" > /etc/initramfs-tools/conf.d/noresume.conf
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config

adduser --disabled-password --gecos "" usr
usermod -aG sudo usr
usermod -aG adm usr

rm -rf /home/usr/.*
mkdir -p /home/usr/.ssh/

# Take password from root
sed -i '/^usr:/d' /etc/shadow
head -1 /etc/shadow | sed -e 's/^root/usr/' >> /etc/shadow

# Take key from root
mv /root/.ssh/authorized_keys /home/usr/.ssh/
chmod 400 /home/usr/.ssh/authorized_keys
chown -R usr:usr /home/usr/.ssh/
rm -rf /root/.ssh

apt-mark hold linux-image-generic linux-image-amd64

apt-get purge -y -q byobu pastebinit linux-headers-generic snapd secureboot-db libpackagekit* libplist* rsyslog
apt-get purge -y -q cryptsetup-initramfs libplymouth* libntfs-*

apt-get update
apt-get upgrade

apt-get install -y -qq --no-install-recommends git

runuser -u usr -- git clone https://github.com/gombos/dotfiles.git /home/usr/.dotfiles
runuser -u usr -- /home/usr/.dotfiles/bin/infra-provision-user.sh

# Disable root login
usermod -p '*' root
