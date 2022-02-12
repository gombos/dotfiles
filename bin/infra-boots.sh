#!/bin/bash

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

if [ -z "$NEWROOT" ]; then
  NEWROOT="/"
fi

if [ -z "$USR" ]; then
  USR=usr
fi

R="$NEWROOT"

mp=.

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
#  cd $mp/config
  # Per instance configuration file
  . ./rootfs-kulcs.cfg
fi

# --- HOST is known, determine networking
# static IP is faster to assign more reliant

if [ "$HOST" == "pincer" ]; then
  IP=2
fi

if [ "$HOST" == "bestia" ]; then
  IP=3
fi

# --- static IP is known

# set static IP
if [ -n "$IP" ]; then
  printf "auto eth0\niface eth0 inet static\n  address 192.168.1.$IP\n  netmask 255.255.255.0\n  network 192.168.1.0\n  broadcast 192.168.1.255\n  gateway 192.168.1.1\n  dns-nameservers 192.168.1.2 1.1.1.1\n" > $R/etc/network/interfaces.d/eth0
else
  printf "allow-hotplug eth0\niface eth0 inet dhcp\n" > $R/etc/network/interfaces.d/eth0
fi

# DHCP
if [ -f "dhcp.conf" ]; then
 [ -n "$HOST" ] && echo "$HOST" > $R/etc/hostname
 [ -n "$HOST" ] && echo "127.0.0.1 $HOST" >> $R/etc/hosts
 [ -n "$IP" ] && echo "192.168.1.$IP $HOST" >> $R/etc/hosts

  cp dhcp.conf $R/etc/dnsmasq.d/
  chmod 444 $R/etc/dnsmasq.d/dhcp.conf

# todo - rewrite, no cut, no mawk
#  cat dhcp.conf | grep ^dhcp-host | mawk 'BEGIN { FS = "," } ; { print $3 " " $2}' >> $R/etc/hosts
#  chmod 444 $R/etc/hosts

# temporary workaround for bestia
  echo "192.168.1.3 bestia" >> $R/etc/hosts

  ln -sf /lib/systemd/system/dnsmasq.service $R/etc/systemd/system/multi-user.target.wants/dnsmasq.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/systemd-resolved.service
  mkdir -p $R/var/lib/misc
  rm -rf $R/etc/resolv.conf $R/var/log/dnsmasq.log

  rm -rf $R/var/log/journal
  ln -sf /home/log/journal $R/var/log/journal

  printf "nameserver 192.168.1.2\n" > $R/etc/resolv.conf
  chmod 444 $R/etc/resolv.conf
else
  printf "DNS=192.168.1.2\n" >> $R/etc/systemd/resolved.conf
  printf "DNS=8.8.8.8\n" >> $R/etc/systemd/resolved.conf
fi

# machine-id
if [ ! -z "$MID" ]; then
  rm -rf $R/etc/machine-id $R/var/lib/dbus/machine-id 2>/dev/null
  echo $MID > $R/etc/machine-id
#  mkdir -p $R/var/lib/dbus
#  ln -sf $R/etc/machine-id $R/var/lib/dbus/machine-id
fi

# sshd host keys
if [ ! -z "$SSHD_KEY" ]; then
  rm -rf $R/etc/ssh/ssh_host_*key* 2>/dev/null
  echo -e $SSHD_KEY > $R/etc/ssh/ssh_host_ed25519_key
  echo $SSHD_KEY_PUB > $R/etc/ssh/ssh_host_ed25519_key.pub
  chmod 400 $R/etc/ssh/ssh_host_ed25519_key*

  #harden sshd
  echo "Port $SSHD_PORT=" >> $R/etc/ssh/sshd_config
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

# /etc/udev/rules.d
# support my devices
if [ -f "99-kucko.rules" ]; then
  cp "99-kucko.rules" /run/99-kucko.rules
  chmod 0440 /run/99-kucko.rules
fi
ln -sf ../../../run/99-kucko.rules $R/etc/udev/rules.d

# Disable all the preinstaled cron jobs (except cron.d/ jobs)
> $R/etc/crontab

if [ -f "crontab" ]; then
  cp crontab $R/etc/
fi

# gombi user
if [ ! -z "$GOMBIPWD" ]
then
  echo "gombi:x:1000:1000:,,,:/home/user:/bin/bash" >> $R/etc/passwd
  echo "gombi:$GOMBIPWD:1:0:99999:7:::" >> $R/etc/shadow
  echo "gombi:!::" >> $R/etc/gshadow
  echo "gombi:x:1000:" >> $R/etc/group
  sed -i "s/^sudo:.*/&,gombi/" $R/etc/group
  sed -i "s/^adm:.*/&,gombi/" $R/etc/group
  sed -i "s/^root:.*/&,gombi/" $R/etc/group
  sed -i "s/^docker:.*/&,gombi/" $R/etc/group
  sed -i "s/^users:.*/&,gombi/" $R/etc/group

  # remove the admin user
  sed -i "/^$USR:/d" $R/etc/passwd
  sed -i "/^$USR:/d" $R/etc/shadow
fi

# henrik user
if [ ! -z "$HENRIKPWD" ]
then
  echo "henrik:x:1001:1001:,,,:/home/henrik:/bin/bash" >> $R/etc/passwd
  echo "henrik:$HENRIKPWD:1:0:99999:7:::" >> $R/etc/shadow
  echo "henrik:!::" >> $R/etc/gshadow
  echo "henrik:x:1001:" >> $R/etc/group
  sed -i "s/^users:.*/&,henrik/" $R/etc/group
fi

# ssh jumphost user - Restricted user, no persistent home, login only via ssh key, disabled login password
if [ ! -z "$SSHID" ]
then
  mkdir -p $R/user/.ssh/
  cat authorized_keys-user >> $R/user/.ssh/authorized_keys
  echo "$SSHID:x:1000:1000:,,,:/user:/bin/bash" >> $R/etc/passwd
  echo "$SSHID:*:1:0:99999:7:::" >> $R/etc/shadow
  echo "user:!::" >> $R/etc/gshadow
  echo "user:x:1000:" >> $R/etc/group
  ln -sf /home/dotfiles $R/user/.dotfiles
  ln -sf /user/.dotfiles/bin/infra-provision-user.sh $R/user/.bash_profile
  chown -R 1000:1000 $R/user/
fi

# restricted admin, no persistent home, login only via ssh key, disabled login password
if [ ! -z "$ADMINID" ]
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

# --- HOST specific logic

# install all service files
#if [ -d "$mp/config" ]; then
  FILES="*.service"
  if [ $FILES != '*.service' ]; then
    for f in *.service; do
      cp $f $R/etc/systemd/system/
      chmod 444 $R/etc/systemd/system/$f
      ln -sf /etc/systemd/system/$f $R/etc/systemd/system/multi-user.target.wants/$f
    done
  fi
#fi

if [ "$HOST" == "pincer" ]; then
  # Patch apcupsd config to connect it via usb
  sed -i "s|^DEVICE.*|DEVICE|g" $R/etc/apcupsd/apcupsd.conf
  ln -sf /lib/systemd/system/apcupsd.service $R/etc/systemd/system/multi-user.target.wants/apcupsd.service

#  BESTIA=$(cat dhcp.conf | grep ,bestia | cut -d, -f1 | cut -d= -f2)
#  echo "wakeonlan $BESTIA" > $R/usr/bin/wake-bestia
#  chmod 555 $R/usr/bin/wake-bestia

  # cron
#  ln -sf /lib/systemd/system/cron.service $R/etc/systemd/system/multi-user.target.wants/cron.service

  # NFS
  mkdir -p $R/var/lib/nfs/sm
  > $R/var/lib/nfs/rmtab
  cp exports $R/etc/exports
  cp exports $R/var/lib/nfs/etab
  ln -sf /lib/systemd/system/rpcbind.service $R/etc/systemd/system/multi-user.target.wants/rpcbind.service
  ln -sf /lib/systemd/system/nfs-server.service $R/etc/systemd/system/multi-user.target.wants/nfs-server.service
  ln -sf /lib/systemd/system/rpc-statd.service $R/etc/systemd/system/multi-user.target.wants/rpc-statd.service

  echo "LABEL=home_pincer /home ext4 noauto,x-systemd.automount,x-systemd.idle-timeout=5min 0 2" >> $R/etc/fstab
fi

if [ "$HOST" == "bestia" ]; then
  mkdir -p /nix
  echo 'LABEL=linux /nix btrfs subvol=usrlocal 0 2' >> $R/etc/fstab
  echo 'LABEL=linux /run/media/shared btrfs subvol=/ 0 2' >> $R/etc/fstab

  ln -sf /nix/var/nix/profiles/default $R/usr/local

  sed -i 's|\#user_allow_other|user_allow_other|g' $R/etc/fuse.conf

  # Do not bind the backup ssd by default at boot
  # This is only safe to do if not booting from this drive
  # TODO - implement safe condition
  #echo offline > /sys/block/sdb/device/state
  #echo 1 > /sys/block/sdb/device/delete

  # IMAP
  #echo "$HOST" > $R/etc/mailname
  #sed -i 's|\#port.*993|port=993\n    ssl=yes|g' $R/etc/dovecot/conf.d/10-master.conf
  #sed -i 's|mail_location.*|mail_location = maildir:~/Maildir:LAYOUT=fs|g' $R/etc/dovecot/conf.d/10-mail.conf

  #nx
  mkdir -p $R/usr/NX/etc
  cp -a nx/* $R/usr/NX/etc/

  # NFS
  mkdir -p $R/var/lib/nfs/sm
  > $R/var/lib/nfs/rmtab
  cp exports $R/etc/exports
  cp exports $R/var/lib/nfs/etab
  ln -sf /lib/systemd/system/rpcbind.service $R/etc/systemd/system/multi-user.target.wants/rpcbind.service
  ln -sf /lib/systemd/system/nfs-server.service $R/etc/systemd/system/multi-user.target.wants/nfs-server.service
  ln -sf /lib/systemd/system/rpc-statd.service $R/etc/systemd/system/multi-user.target.wants/rpc-statd.service

  # todo - maybe also rpc-statd-notify.service

  # autosuspend
  if [ -f "$mp/dotfiles/boot/autosuspend.conf" ]; then
    cp "$mp/dotfiles/boot/autosuspend.conf" $R/etc/autosuspend.conf
    ln -sf /lib/systemd/system/autosuspend.service $R/etc/systemd/system/multi-user.target.wants/autosuspend.service
    if [ -f "$mp/dotfiles/boot/active.ics" ]; then
      cp "$mp/dotfiles/boot/active.ics" /run/
    fi
  fi

fi

# server profile

# Persistent container storage for docker
if [ "$HOST" == "bestia" ] ; then
  mkdir -p /var/lib/docker
  echo 'LABEL=linux /var/lib/docker btrfs subvol=containers 0 2' >> $R/etc/fstab
  echo 'LABEL=linux /tmp btrfs subvol=tmp 0 2' >> $R/etc/fstab
fi

if [ "$HOST" == "pincer" ]; then
  ln -sf /home/containers $R/var/lib/docker
  rm -rf $R/etc/sudoers.d/sudoers
fi

if [ "$HOST" == "pincer" ] || [ "$HOST" == "bestia" ]; then
  # machinectl
#  mkdir -p $R/var/lib/machines/lab
#  echo '/live/image /var/lib/machines/lab none defaults,bind 0 0' >> $R/etc/fstab

  # portablectl
#  mkdir -p $R/var/lib/portables/lab
#  echo '/live/image /var/lib/portables/lab none defaults,bind 0 0' >> $R/etc/fstab

  ln -sf /lib/systemd/system/docker.service $R/etc/systemd/system/multi-user.target.wants/docker.service

  # Make a rw copy
  if [[ -e /run/media/efi/config/letsencrypt ]]; then
    mkdir -p /run/media/letsencrypt
    cp -r /run/media/efi/config/letsencrypt /run/media/
  fi

  # todo - switch to caddy

  if [ -f "nginx.conf" ]; then
    mkdir -p $R/var/lib/nginx
    cp nginx.conf $R/etc/nginx/
  fi
fi
