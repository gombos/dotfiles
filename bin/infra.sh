#!/bin/bash

# Runs when rootfs is computed
# Could run either offline or only at first boot
# It should not run at each boot

cd /

mkdir -p /config/updates/etc/ssh /config/updates/etc/network /isos

if [ -n "$SCRIPT" ]; then
  eval $SCRIPT
  echo $SCRIPT >> /config/rootfs-kulcs.cfg
fi

# Elevete some files so that they are picked up by ISO
cp /etc/ssh/sshd_config  /config/updates/etc/ssh
cp /etc/network/interfaces /config/updates/etc/network

cp /etc/hosts /config/updates/etc
cp /etc/rsyslog.conf /config/updates/etc

# Might run at first boot, services might be already running
echo "PasswordAuthentication no" >> /config/updates/etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /config/updates/etc/ssh/sshd_config
echo "UsePAM no" >> /config/updates/etc/ssh/sshd_config
echo "PermitRootLogin no" >> /config/updates/etc/ssh/sshd_config

if [ -n "$USR" ]; then
  echo "AllowUsers $USR" >> /config/updates/etc/ssh/sshd_config
fi

if [ -n "$SSHDPORT" ]; then
  echo "Port ${SSHDPORT}" >> /config/updates/etc/ssh/sshd_config
fi

[ -n "$LABEL" ] && echo "$LABEL" > /config/updates/etc/hostname
[ -n "$LABEL" ] && echo "127.0.0.1 $LABEL" >> /config/updates/etc/hosts

if [ -n "$LOG" ]; then
  echo "*.*                     @${LOG}" >> /config/updates/etc/rsyslog.conf
fi

wget --quiet https://github.com/gombos/dotfiles/releases/download/iso/linux.iso -O /isos/linux.iso

cat > /config/grub.cfg << 'EOF'
isolabel=linode-root
OVERRIDE="systemd.unit=multi-user.target systemd.want=getty@tty1.service console=ttyS0,19200n8 systemd.hostname=pincer systemd.mask=home systemd.mask=NetworkManager systemd.mask=NetworkManager-wait-online"
EOF

# Take password from root
echo -n "GOMBIPWD='" >> /config/rootfs-kulcs.cfg
head -1 /etc/shadow | cut -d: -f2 | tr '\n' "'" >> /config/rootfs-kulcs.cfg
echo "" >> /config/rootfs-kulcs.cfg

# Disable root login
rm -rf /root/.ssh
usermod -p '*' root

if [ -n "$USR" ]; then
  # Take ssh key from root
  mkdir -p /home/$USR/.ssh/
  mv /root/.ssh/authorized_keys /home/$USR/.ssh/
  chmod 400 /home/$USR/.ssh/authorized_keys

  # todo - switch to wget and unzip instead of git
  apt-get update
  apt-get install -y -qq --no-install-recommends git
  git clone https://github.com/gombos/dotfiles.git /home/$USR/.dotfiles
  chown -R 1000:1000 /home/$USR

  cp /home/$USR/.dotfiles/boot/grub.cfg /boot/grub/custom.cfg

  # Run as root when iso boots - runs at each boot
  ln -sf /run/initramfs/isoscan/home/$USR/.dotfiles/bin/infra-boots.sh /config/infra-boots.sh
fi

/sbin/reboot
