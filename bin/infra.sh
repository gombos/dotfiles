#!/bin/bash

# Runs on image boot first and pulls the iso and boots into ISO
# Do not assume a specific distro (or package manager) if possible

mkdir -p /config/updates/etc/network /config/updates/etc/rsyslog.d

# TODO - find a more generic way to pass secrets

#

# TODO - SSHD_KEY_PUB, SSHD_KEY
if [ -n "$SCRIPT" ]; then
  eval $SCRIPT
  echo $SCRIPT >> /config/rootfs-kulcs.cfg
fi

if [ -n "$LOG" ]; then
  echo "*.* @$LOG" >> /config/updates/etc/rsyslog.d/10-default.conf
  logger "booting"
fi

# use base64
if [ -n "$TS" ]; then
  mkdir -p /config/updates/var/lib/tailscale/
  echo "$TS" | base64 --decode > /config/updates/var/lib/tailscale/tailscaled.state
  echo "$TS" > /config/updates/var/lib/tailscale/tailscaled.orig
  echo test > /config/updates/var/lib/tailscale/tailscaled.test
fi

export /config/updates/debug

# use base64
#if [ -n "$SSHD" ]; then
  mkdir -p /config/updates/etc/ssh/
  echo "$SSHD" | base64 --decode > /config/updates/etc/ssh/ssh_host_ed25519_key
  echo "$SSHD" > /config/updates/etc/ssh/ssh_host_ed25519_key.orig
  echo test > /config/updates/etc/ssh/ssh_host_ed25519_key.test
#fi

# Elevate some files so that they are picked up by ISO
cp /etc/network/interfaces /config/updates/etc/network

wget --quiet https://raw.githubusercontent.com/gombos/dotfiles/main/boot/grub.cfg -O /boot/grub/custom.cfg
wget --quiet https://raw.githubusercontent.com/gombos/dotfiles/main/bin/infra-boots.sh -O /config/infra-boots.sh
wget --quiet https://github.com/gombos/dotfiles/releases/download/iso/linux.iso -O /linux.iso

cat > /config/grub.cfg << EOF
isolabel=linode-root
OVERRIDE="systemd.unit=multi-user.target systemd.wants=getty@tty1.service console=ttyS0,19200n8 systemd.hostname=$LABEL systemd.wants=dev-disk-by\x2dlabel-swap systemd.machine_id=99a1f8fc81314877bcf464fc33951494"
EOF

# rd.live.overlay=/dev/sda:/overlay.img

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

# Add a well-known label to swap
swapoff -a
swaplabel -L swap /dev/sdb

# reboot into ISO
reboot
