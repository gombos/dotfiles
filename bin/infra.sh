#!/bin/bash

# Might run at first boot, services might be already running

echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
echo "UsePAM no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "AllowUsers usr" >> /etc/ssh/sshd_config
echo "Port ${SSHDPORT}" >> /etc/ssh/sshd_config

systemctl restart sshd

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

# Disable root login
usermod -p '*' root

echo "RESUME=none" > /etc/initramfs-tools/conf.d/noresume.conf

apt-get update
apt-get install -y -qq --no-install-recommends git

runuser -u usr -- git clone https://github.com/gombos/dotfiles.git /home/usr/.dotfiles
runuser -u usr -- /home/usr/.dotfiles/bin/infra-provision-user.sh

apt-get install -y -qq --no-install-recommends python3-pip micro

# Takes time, do it last
apt-mark hold linux-image-amd64

apt-get purge -y -q rsyslog telnet traceroute os-prober tasksel javascript-common vim-* whiptail publicsuffix nano dmidecode hdparm iso-codes mtr-tiny pciutils reportbug whois

# Ubuntu things
# apt-mark hold linux-image-generic
#apt-get purge -y -q byobu
#apt-get purge -y -q pastebinit
#apt-get purge -y -q linux-headers-generic
#apt-get purge -y -q snapd
#apt-get purge -y -q secureboot-db
#apt-get purge -y -q libpackagekit*
#apt-get purge -y -q libplist*
#apt-get purge -y -q cryptsetup-initramfs
#apt-get purge -y -q libplymouth*
#apt-get purge -y -q libntfs-*

apt-get -y -qq autoremove
dpkg --list |grep "^rc" | cut -d " " -f 3 | xargs sudo dpkg --purge

apt-get -y -qq upgrade
