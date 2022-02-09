#!/bin/bash

cd /

# Might run at first boot, services might be already running

echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
echo "UsePAM no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config

if ! [ -z "$USR" ]; then
  echo "AllowUsers $USR" >> /etc/ssh/sshd_config
fi

if ! [ -z "$SSHDPORT" ]; then
  echo "Port ${SSHDPORT}" >> /etc/ssh/sshd_config
fi

systemctl restart sshd

if [ -d /etc/initramfs-tools ]; then
  echo "RESUME=none" > /etc/initramfs-tools/conf.d/noresume.conf
fi

apt-get update

if ! [ -z "$USR" ]; then
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

  install_my_package.sh git

  runuser -u $USR -- git clone https://github.com/gombos/dotfiles.git /home/$USR/.dotfiles
  runuser -u $USR -- /home/$USR/.dotfiles/bin/infra-provision-user.sh

  if [ -d /home/$USR/.dotfiles/bin ]; then
    PATH=/home/$USR/.dotfiles/bin:$PATH
  fi
fi

# Dependencies for the rest of the script
install_my_packages.sh packages-core.l

apt-mark hold linux-image-amd64

apt-get purge -y -q cloud-init sysstat rsyslog telnet traceroute os-prober tasksel javascript-common vim-* whiptail publicsuffix nano mtr-tiny reportbug whois libldap-common liblockfile-bin libsasl2-modules dnsutils apt-listchanges liblognorm5 debconf-i18n 2>/dev/null >/dev/null

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

# Cleanup packages only needed during building the rootfs
apt-get purge -y -qq linux-*headers-* fuse libllvm11 2>/dev/null >/dev/null

apt-get -y -qq autoremove
dpkg --list |grep "^rc" | cut -d " " -f 3 | xargs sudo dpkg --purge
apt-get clean

apt-get -y -qq upgrade

[ -n "$LABEL" ] && echo "$LABEL" > $R/etc/hostname
[ -n "$LABEL" ] && echo "127.0.0.1 $LABEL" >> $R/etc/hosts

# populate /usr/local
packages-nix

# todo - find a way to do /go/efi/config

if [ -n "$LOG" ]; then
cat > /lib/systemd/system/papertrail.service << EOF
[Unit]
Description=Papertrail
After=systemd-journald.service
Requires=systemd-journald.service
[Service]
ExecStart=/bin/sh -c "journalctl -f | nc --ssl $LOG"
TimeoutStartSec=0
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF

ln -sf /lib/systemd/system/papertrail.service /etc/systemd/system/multi-user.target.wants/
fi

# cleanup
infra-clean-linux.sh /
rm -rf tmp/*

# Avoid suprises later
reboot
