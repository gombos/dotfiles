#!/bin/bash

# Runs when rootfs is computed
# Could run either offline or only at first boot
# It should not run at each boot

cd /

if [ -n "$SCRIPT" ]; then
  eval $SCRIPT
  mkdir -p /config/updates/etc/ssh /config/updates/etc/network
  echo $SCRIPT >> /config/rootfs-kulcs.cfg
fi

# Might run at first boot, services might be already running

echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
echo "UsePAM no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config

if [ -n "$USR" ]; then
  echo "AllowUsers $USR" >> /etc/ssh/sshd_config
fi

if [ -n "$SSHDPORT" ]; then
  echo "Port ${SSHDPORT}" >> /etc/ssh/sshd_config
fi

systemctl restart sshd

if [ -d /etc/initramfs-tools ]; then
  echo "RESUME=none" > /etc/initramfs-tools/conf.d/noresume.conf
fi

apt-get update

# Things only run in the cloud
if [ -n "$USR" ]; then
  adduser --disabled-password --gecos "" $USR
  usermod -aG sudo $USR
  usermod -aG adm $USR

  rm -rf /home/$USR/.*
  mkdir -p /home/$USR/.ssh/

  # Take password from root
  sed -i "/^usr:/d" /etc/shadow
  SHADOW=$(head -1 /etc/shadow | sed -e "s/^root/usr/")
  echo $SHADOW >> /etc/shadow

  echo $SHADOW > /config/shadow
  echo -n "IPWD=\'" >> /config/rootfs-kulcs.cfg
  echo -n $SHADOW | cut -d: -f2 >> /config/rootfs-kulcs.cfg
  echo "\'" >> /config/rootfs-kulcs.cfg

  # Todo - elevate this to the iso as well

  # Take key from root
  mv /root/.ssh/authorized_keys /home/$USR/.ssh/
  chmod 400 /home/$USR/.ssh/authorized_keys
  chown -R $USR:$USR /home/$USR/.ssh/
  rm -rf /root/.ssh

  # Disable root login
  usermod -p '*' root

  apt-get install -y -qq --no-install-recommends git

  runuser -u $USR -- git clone https://github.com/gombos/dotfiles.git /home/$USR/.dotfiles
  runuser -u $USR -- /home/$USR/.dotfiles/bin/infra-provision-user.sh

  if [ -d /home/$USR/.dotfiles/bin ]; then
    PATH=/home/$USR/.dotfiles/bin:$PATH
  fi

  # Dependencies for the rest of the script
  # todo - improve install script
  # cp /home/$USR/.dotfiles/packages/packages-core.l /tmp/
  # install_my_packages.sh packages-core.l

  # not needed this is only done for the iso
  # populate /usr/local
  # packages-nix
  mkdir -p isos/
  cd isos
  wget --quiet https://github.com/gombos/dotfiles/releases/download/iso/linux.iso
  cd ..

  cp /home/$USR/.dotfiles/boot/grub.cfg /boot/grub/custom.cfg

  mkdir -p /config

cat > /config/grub.cfg << 'EOF'
isolabel=linode-root
OVERRIDE="systemd.unit=multi-user.target systemd.want=getty@tty1.service console=ttyS0,19200n8 systemd.hostname=pincer systemd.mask=home systemd.mask=NetworkManager systemd.mask=NetworkManager-wait-online"
EOF

fi

apt-mark hold linux-image-amd64

apt-get purge -y -q cloud-init sysstat telnet traceroute os-prober tasksel javascript-common vim-* whiptail publicsuffix nano mtr-tiny reportbug whois libldap-common liblockfile-bin libsasl2-modules dnsutils apt-listchanges debconf-i18n 2>/dev/null >/dev/null

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
dpkg --list |grep "^rc" | cut -d " " -f 3 | xargs dpkg --purge
apt-get clean

apt-get -y -qq upgrade

[ -n "$LABEL" ] && echo "$LABEL" > $R/etc/hostname
[ -n "$LABEL" ] && echo "127.0.0.1 $LABEL" >> $R/etc/hosts

if [ -n "$LOG" ]; then
echo "*.*                   	@${LOG}" >> /etc/rsyslog.conf
fi

# cleanup
infra-clean-linux.sh /
rm -rf tmp/*

# Only on Linode
if [ -n "$SCRIPT" ]; then

# Elevete some files so that they are picked up by ISO
cp /etc/ssh/sshd_config  /config/updates/etc/ssh
cp /etc/network/interfaces /config/updates/etc/network

cp /etc/hostname /config/updates/etc
cp /etc/hosts /config/updates/etc
cp /etc/rsyslog.conf /config/updates/etc

# Run as root when iso boots - runs at each boot
ln -sf /run/initramfs/isoscan/home/$USR/.dotfiles/bin/infra-boots.sh /config/infra-boots.sh

reboot

fi
