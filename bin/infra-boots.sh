#!/bin/bash

if [ -z "$NEWROOT" ]; then
  NEWROOT="/"
fi

if [ -z "$USR" ]; then
  USR=usr
fi

R="$NEWROOT"
UPDATES="updates"

# command line
for x in $(cat /proc/cmdline); do
  case $x in
  systemd.hostname=*)
    HOST=${x#systemd.hostname=}
  ;;
  esac
done

# Per-host configuration is optional
if [ -f "rootfs-kulcs.cfg" ]; then
  . ./rootfs-kulcs.cfg
fi

# --- HOST is known, determine networking
# static IP is faster to assign more reliant

NET=192.168.1

if [ "$HOST" = "kispincer" ]; then
  IP=2
fi

if [ "$HOST" = "bestia" ]; then
  IP=3
fi

if [ "$HOST" = "nagybestia" ]; then
  IP=5
fi

if [ "$HOST" = "p" ]; then
  NET=192.168.0
  IP=100
fi

if [ "$HOST" = "h" ]; then
  NET=192.168.0
  IP=101
fi

# --- static IP is known

# set static IP
if [ -n "$IP" ]; then
  printf "allow-hotplug eth0\niface eth0 inet static\n  ethernet-wol g\n  address $NET.$IP\n  netmask 255.255.255.0\n  network $NET.0\n  broadcast $NET.255\n  gateway $NET.1\n  dns-nameservers 1.1.1.1\n   up sleep 5; ethtool -s eth0 speed 1000 duplex full\n" > $R/etc/network/interfaces.d/eth0
fi

# updates
if [ -d "$UPDATES" ]; then
  cp -a $UPDATES/* $R/
fi

[ -n "$HOST" ] && echo "127.0.0.1 $HOST" >> $R/etc/hosts

# DHCP
if [ -f "$R/etc/dnsmasq.d/dhcp.conf" ]; then
 [ -n "$HOST" ] && echo "$HOST" > $R/etc/hostname
 [ -n "$IP" ] && echo "$NET.$IP $HOST" >> $R/etc/hosts

  chmod 444 $R/etc/dnsmasq.d/dhcp.conf

# todo - rewrite, no cut, no mawk
#  cat dhcp.conf | grep ^dhcp-host | mawk 'BEGIN { FS = "," } ; { print $3 " " $2}' >> $R/etc/hosts
#  chmod 444 $R/etc/hosts

# temporary workaround for bestia
  echo "192.168.1.7 bestia" >> $R/etc/hosts

  echo "nameserver 127.0.0.53" > $R/etc/resolv.conf
  echo "options edns0 trust-ad" >> $R/etc/resolv.conf

  mkdir -p $R/var/lib/misc
else
  printf "DNS=8.8.8.8\n" >> $R/etc/systemd/resolved.conf
fi

# sshd host keys
if [ -n "$SSHD_KEY" ]; then
  rm -rf $R/etc/ssh/ssh_host_*key* 2>/dev/null
  echo -e $SSHD_KEY > $R/etc/ssh/ssh_host_ed25519_key
  echo "$SSHD_KEY_PUB" > $R/etc/ssh/ssh_host_ed25519_key.pub
  chmod 400 $R/etc/ssh/ssh_host_ed25519_key*
fi

# configure vmware service
if [ -d "vmware" ]; then
  mkdir -p $R/var/lib/vmware
  ln -sf /run/media/shared/vm/ "$R/var/lib/vmware/Shared VMs"
  cp license-* $R/etc/vmware/
  chmod 444 $R/etc/vmware/license-*
  cp vmware/* $R/etc/vmware/hostd/
  sed -i 's/^acceptOVFEULA .*/acceptOVFEULA = "yes"/' $R/etc/vmware/config
  sed -i 's/^acceptEULA .*/acceptEULA = "yes"/' $R/etc/vmware/config
  sed -i 's/^installerDefaults.autoSoftwareUpdateEnabled .*/installerDefaults.autoSoftwareUpdateEnabled = "no"/' $R/etc/vmware/config
  sed -i 's/^installerDefaults.dataCollectionEnabled .*/installerDefaults.dataCollectionEnabled = "no"/' $R/etc/vmware/config
  sed -i 's/^installerDefaults.dataCollectionEnabled.initialized .*/installerDefaults.dataCollectionEnabled.initialized = "yes"/' $R/etc/vmware/config
fi

# USR user
if [ -n "$USRPWD" ]
then
  # remove the default rootfs user
  sed -i "/^$USR:/d" $R/etc/passwd
  sed -i "/^$USR:/d" $R/etc/shadow

  echo "$USR:x:1000:1000:,,,:/home/$USR:/bin/bash" >> $R/etc/passwd
  echo "$USR:$USRPWD:1:0:99999:7:::" >> $R/etc/shadow
  sed -i "s/^docker:.*/&,$USR/" $R/etc/group
  sed -i "s/^users:.*/&,$USR/" $R/etc/group
fi

# henrik user
if [ -n "$HENRIKPWD" ]
then
  echo "henrik:x:1001:1001:,,,:/home/henrik:/bin/bash" >> $R/etc/passwd
  echo "henrik:$HENRIKPWD:1:0:99999:7:::" >> $R/etc/shadow
  echo "henrik:!::" >> $R/etc/gshadow
  echo "henrik:x:1001:" >> $R/etc/group
  sed -i "s/^users:.*/&,henrik/" $R/etc/group
fi

# ssh jumphost user - Restricted user, no persistent home, login only via ssh key, disabled login password
if [ -n "$SSHID" ]
then
  mkdir -p $R/user/.ssh/
  cat authorized_keys-user >> $R/user/.ssh/authorized_keys
  echo "$SSHID:x:2000:2000:,,,:/user:/bin/bash" >> $R/etc/passwd
  echo "$SSHID:*:1:0:99999:7:::" >> $R/etc/shadow
  echo "user:!::" >> $R/etc/gshadow
  echo "user:x:2000:" >> $R/etc/group
  ln -sf /home/dotfiles $R/user/.dotfiles
  ln -sf /user/.dotfiles/bin/infra-provision-user.sh $R/user/.bash_profile
  chown -R 2000:2000 $R/user/
fi

# restricted admin, no persistent home, login only via ssh key, disabled login password
if [ -n "$ADMINID" ]
then
  mkdir -p $R/admin/.ssh
  cat authorized_keys >> $R/admin/.ssh/authorized_keys
  echo "$ADMINID:x:501:27:,,,:/admin:/bin/bash" >> $R/etc/passwd
  echo "$ADMINID:$ADMINPWD:1:0:99999:7:::" >> $R/etc/shadow
  sed -i "s/^docker:.*/&,$ADMINID/" $R/etc/group
  ln -sf /home/dotfiles-admin $R/admin/.dotfiles
  ln -sf /admin/.dotfiles/bin/infra-provision-user.sh $R/admin/.bash_profile
  chown -R 501:27 $R/admin/

  # remove the admin user
  sed -i "/^$USR:/d" $R/etc/passwd
  sed -i "/^$USR:/d" $R/etc/shadow
fi

if [ "$HOST" = "nagybestia" ]; then
  printf "nameserver 8.8.8.8\n" >> $R/etc/resolv.conf
  echo 'LABEL=linux /run/media/shared btrfs subvol=/ 0 2' >> $R/etc/fstab
  sed -i 's|\#user_allow_other|user_allow_other|g' $R/etc/fuse.conf
  # Persistent container storage for docker
  mkdir -p /var/lib/docker
  echo 'LABEL=linux /var/lib/docker btrfs subvol=containers 0 2' >> $R/etc/fstab
fi

if [ "$HOST" = "bestia" ]; then
  ln -sf /lib/systemd/system/systemd-networkd.service $R/etc/systemd/system/multi-user.target.wants/systemd-networkd.service
  ln -sf /lib/systemd/system/wpa_supplicant\@.service $R/etc/systemd/system/multi-user.target.wants/wpa_supplicant\@wlo1.service
  rm -rf $R/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
  rm -rf $R/etc/systemd/system/dbus-fi.w1.wpa_supplicant1.service
  ln -sf /dev/null $R/etc/systemd/system/wpa_supplicant.service
  mkdir $R/var/lib/bluetooth

  # NFS
  mkdir -p $R/var/lib/nfs/sm
  > $R/var/lib/nfs/rmtab
  cp $R/etc/exports $R/var/lib/nfs/etab

  echo 'LABEL=linux /run/media/shared btrfs nofail,subvol=/ 0 2' >> $R/etc/fstab

  sed -i 's|\#user_allow_other|user_allow_other|g' $R/etc/fuse.conf

  ln -sf /run/initramfs/isoscan $R/go/efi

  # Do not bind the backup ssd by default at boot
  # This is only safe to do if not booting from this drive
  # TODO - implement safe condition
  #echo offline > /sys/block/sdb/device/state
  #echo 1 > /sys/block/sdb/device/delete

  # IMAP
  #echo "$HOST" > $R/etc/mailname
  #sed -i 's|\#port.*993|port=993\n    ssl=yes|g' $R/etc/dovecot/conf.d/10-master.conf
  #sed -i 's|mail_location.*|mail_location = maildir:~/Maildir:LAYOUT=fs|g' $R/etc/dovecot/conf.d/10-mail.conf

  # Persistent container storage for docker
  mkdir -p /var/lib/docker /tmp
  echo 'LABEL=linux /var/lib/docker btrfs nofail,subvol=containers 0 2' >> $R/etc/fstab
  echo 'LABEL=linux /tmp btrfs nofail,subvol=tmp 0 2' >> $R/etc/fstab
fi

if [ "$HOST" = "p" ]; then
  echo 'HandleLidSwitch=ignore' >> $R/etc/systemd/logind.conf
fi

echo "PasswordAuthentication no" >> $R/etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> $R/etc/ssh/sshd_config
echo "UsePAM no" >> $R/etc/ssh/sshd_config
echo "PermitRootLogin no" >> $R/etc/ssh/sshd_config

if [ -n "$SSHD_PORT" ]; then
  echo "Port $SSHD_PORT" >> $R/etc/ssh/sshd_config

mkdir -p $R/etc/systemd/system/ssh.socket.d
cat >$R/etc/systemd/system/ssh.socket.d/listen.conf <<EOF
[Socket]
ListenStream=
ListenStream=$SSHD_PORT
EOF

fi

if [ "$HOST" = "pincer" ]; then
  # networking
  printf "DNS=97.107.133.4\n" >> $R/etc/systemd/resolved.conf
  rm $R/etc/network/interfaces.d/*

  # filesystem
  mount /run/initramfs/isoscan -o remount,rw

  rm -rf $R/home
  ln -sf /run/initramfs/isoscan/home $R/home

  ln -sf /run/initramfs/isoscan $R/go/efi

  # Persistent container storage for docker on the host
  mkdir -p $R/go/efi/tmp/docker
  ln -sf  /go/efi/tmp/docker $R/var/lib/docker

  if [ -n "$USR" ]; then
    echo "AllowUsers $USR" >> $R/etc/ssh/sshd_config
  fi
fi

# update /run
cd /run/initramfs/isoscan/config/updates/run
find . -depth -type d -exec mkdir -p "/run/{}" \;
find . -depth \! -type d -exec cp -a "{}" "/run/{}" \;
cd -

# first boot of a new instance, run all the “per-instance” configuration

# Warning: error in this file will likely lead to failure to boot

# Idea: detect if cloud-init is installed in the image and run the script during later in the boot phase
# Any of thid is needed when a container is initialized ?
# For LXC-like containers, ssh keys are needed
# also - thsi is a useful way to run containers - https://medium.com/swlh/docker-and-systemd-381dfd7e4628

# Consider only testing/changing this file in a development environment with access to console

# This script logs to /run/initramfs/rdexec.out
# Determine where this script is called from - either as a dracut hook or as a cloud-init phase or 'docker run'

# This script is optional for containers, that are not "booted" and do not initialize systemd. Keep it that way

# cloud-init does similar things

# Do not change /usr to allow ro mount
# Ideally only make changes in /var
# To avoid manipulating /etc use kernel arguments when possible
# Instead of changing existing files, try to just add new files
# Keep changing in /run

# Configuration 1 - OverlayRoot
# Rootfs is mounted ro and EFI partition is mounted as ro to customize rootfs overlay
# /run can be used to create new files and directories that are not persistent between boots
# Symlink /etc to /run when possible - use relative links. This will allow editing these files even if etc itself is mounted read-only

# Input:
# - environment variables, /proc filesystem, including /proc/cmdline
# - current directory is set to where the rd.exec file is located
# - $mp points to EFI partition root
# - $NEWROOT points to root filesystem
# - all changes to root filesystem are made in ram (overlayroot)

# Autodetect the environment
# Disks - /dev/disks, /proc/partitions
# HW - /proc/cpuinfo
# Grub - /proc/cmdline
# Network - DHCP
# rootfs version

# TODO
# move enabling/disabling systemd services out of this file into a kernel command line
