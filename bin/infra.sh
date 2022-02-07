#!/bin/bash

cd /

USR="usr"

# Might run at first boot, services might be already running

echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
echo "UsePAM no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "AllowUsers usr" >> /etc/ssh/sshd_config
echo "Port ${SSHDPORT}" >> /etc/ssh/sshd_config

systemctl restart sshd

adduser --disabled-password --gecos "" $USR
usermod -aG sudo $USR
usermod -aG adm $USR

rm -rf /home/$USR/.*
mkdir -p /home/$USR/.ssh/

# Take password from root
sed -i "/^usr:/d" /etc/shadow
head -1 /etc/shadow | sed -e "s/^root/usr/" >> /etc/shadow

# Take key from root
mv /root/.ssh/authorized_keys /home/$USR/.ssh/
chmod 400 /home/$USR/.ssh/authorized_keys
chown -R $USR:$USR /home/$USR/.ssh/
rm -rf /root/.ssh

# Disable root login
usermod -p '*' root

echo "RESUME=none" > /etc/initramfs-tools/conf.d/noresume.conf

apt-get update
apt-get install -y -qq --no-install-recommends git

runuser -u $USR -- git clone https://github.com/gombos/dotfiles.git /home/$USR/.dotfiles
runuser -u $USR -- /home/$USR/.dotfiles/bin/infra-provision-user.sh

if [ -d /home/$USR/.dotfiles/bin ]; then
  PATH=/home/$USR/.dotfiles/bin:$PATH
fi

# maybe call usrlocal script
apt-get install -y -qq --no-install-recommends unzip micro

# todo - find a way to do /go/efi/config
# todo - papertrail

# Takes time, do it last
apt-mark hold linux-image-amd64

apt-get purge -y -q rsyslog telnet traceroute os-prober tasksel javascript-common vim-* whiptail publicsuffix nano dmidecode hdparm iso-codes mtr-tiny pciutils reportbug whois gcc-9-base libnewt0.52 libgpm2 libldap-common liblockfile-bin libsasl2-modules curl dnsutils apt-listchanges libslang2 liblognorm5 debconf-i18n

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
apt-get clean

apt-get -y -qq upgrade

#infra-clean-linux.sh

hostnamectl set-hostname ${LABEL}

rm -rf tmp/*
rm -rf usr/local

