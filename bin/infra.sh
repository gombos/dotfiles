#!/bin/bash

# Runs when rootfs is computed
# Could run either offline or only at first boot
# It should not run at each boot

cd /

mkdir -p /config/updates/etc/network /isos

if [ -n "$SCRIPT" ]; then
  eval $SCRIPT
  echo $SCRIPT >> /config/rootfs-kulcs.cfg
fi

# Elevete some files so that they are picked up by ISO
cp /etc/network/interfaces /config/updates/etc/network

wget --quiet https://raw.githubusercontent.com/gombos/dotfiles/main/boot/grub.cfg -O /boot/grub/custom.cfg
wget --quiet https://raw.githubusercontent.com/gombos/dotfiles/main/bin/infra-boots.sh -O /config/infra-boots.sh
wget --quiet https://github.com/gombos/dotfiles/releases/download/iso/linux.iso -O /isos/linux.iso

cat > /config/grub.cfg << 'EOF'
isolabel=linode-root
OVERRIDE="systemd.unit=multi-user.target systemd.want=getty@tty1.service console=ttyS0,19200n8 systemd.hostname=$LABEL systemd.mask=home systemd.mask=NetworkManager systemd.mask=NetworkManager-wait-online"
EOF

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

# Disable root login
rm -rf /root/.ssh
usermod -p '*' root

/sbin/reboot
