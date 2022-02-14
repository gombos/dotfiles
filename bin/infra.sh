#!/bin/bash

cd /

if [ -n "$SCRIPT" ]; then
  eval $SCRIPT
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
  head -1 /etc/shadow | sed -e "s/^root/usr/" >> /etc/shadow

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
OVERRIDE="systemd.unit=multi-user.target nomodeset systemd.want=getty@tty1.service console=ttyS0,19200n8"
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

# todo - find a way to do /go/efi/config

if [ -n "$LOG" ]; then
echo "*.*                   	@${LOG}" >> /etc/rsyslog.conf
fi

# cleanup
infra-clean-linux.sh /
rm -rf tmp/*

# Only on Linode
if [ -n "$SCRIPT" ]; then

# Elevete some files so that they are picked up by ISO
mkdir -p /config
cp /etc/ssh/sshd_config  /config
cp /etc/network/interfaces /config
cp /etc/hostname /config
cp /etc/hosts /config
cp /etc/rsyslog.conf /config
cp /etc/resolv.conf /config

# Run as root when iso boots - runs at each boot
# todo - move this to infra-boots.sh
cat > /config/infra-boots.sh << 'THEEND'
#!/bin/bash

R="$NEWROOT"

# /config overlay
cp interfaces $R/etc/network/interfaces
cp sshd_config $R/etc/ssh/sshd_config
cp hostname $R/etc/hostname
cp hosts $R/etc/hosts
cp rsyslog.conf $R/etc/rsyslog.conf

# systemd-resolved.service config
printf "DNS=97.107.133.4\n" >> $R/etc/systemd/resolved.conf
rm $R/etc/network/interfaces.d/*

#echo "/dev/sda  /home ext4 errors=remount-ro  0  1" >> $R/etc/fstab
echo "/dev/sdb  none  swap defaults           0  0" >> $R/etc/fstab

rm -rf $R/lib/systemd/system/home.service
rm -rf $R/etc/systemd/system/local-fs.target.wants/home.service

# Read only home as it point to a read only mount
rm -rf $R/home
cd $R
ln -sf /run/initramfs/isoscan/home/usr home
cd -

THEEND

reboot

fi
