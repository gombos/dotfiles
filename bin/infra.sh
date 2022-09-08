#!/bin/bash

# Runs on image boot first and pulls the iso and boots into ISO
# Do not assume a specific distro (or package manager) if possible

mkdir -p /config/updates/etc/network /isos

if [ -n "$SCRIPT" ]; then
  eval $SCRIPT
  echo $SCRIPT >> /config/rootfs-kulcs.cfg
fi

# Elevate some files so that they are picked up by ISO
cp /etc/network/interfaces /config/updates/etc/network

wget --quiet https://raw.githubusercontent.com/gombos/dotfiles/main/boot/grub.cfg -O /boot/grub/custom.cfg
wget --quiet https://raw.githubusercontent.com/gombos/dotfiles/main/bin/infra-boots.sh -O /config/infra-boots.sh
wget --quiet https://github.com/gombos/dotfiles/releases/download/iso/linux.iso -O /isos/linux.iso

cat > /config/grub.cfg << EOF
isolabel=linode-root
OVERRIDE="systemd.unit=multi-user.target systemd.want=getty@tty1.service console=ttyS0,19200n8 systemd.hostname=$LABEL systemd.mask=home systemd.mask=NetworkManager systemd.mask=NetworkManager-wait-online noquiet rd.debug"
EOF

#noquiet rd.debug rd.live.overlay=/dev/sda:/overlay.img"

# Take password from root
echo -n "USRPWD='" >> /config/rootfs-kulcs.cfg
head -1 /etc/shadow | cut -d: -f2 | tr '\n' "'" >> /config/rootfs-kulcs.cfg
echo "" >> /config/rootfs-kulcs.cfg

if [ -n "$USR" ]; then
  # Take ssh key from root
  mkdir -p /home/$USR/.ssh/
  wget --quiet https://raw.githubusercontent.com/gombos/dotfiles/main/bin/infra-provision.sh -O /home/$USR/.bash_profile

  cp /root/.ssh/authorized_keys /home/$USR/.ssh/
  chmod 400 /home/$USR/.ssh/authorized_keys

  chown -R 1000:1000 /home/$USR
fi

# save RAM - use disk space for root overlay

dd if=/dev/zero of=/overlay.img bs=1M count=1024
mkfs.ext4 /overlay.img
mount /overlay.img /mnt
mkdir /mnt/overlayfs /mnt/ovlwork
umount /mnt

# Disable root login
rm -rf /root/.ssh
usermod -p '*' root

# reboot into ISO
reboot
