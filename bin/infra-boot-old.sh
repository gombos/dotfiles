#!/bin/bash

if [[ -e /dev/disk/by-label/home ]]; then
  mkdir -p /home
#  echo "LABEL=home /home ext4 noauto,x-systemd.automount,x-systemd.idle-timeout=5min 0 2" >> $R/etc/fstab
  mount -t ext4 /dev/disk/by-label/home /home
  ln -sf /home $R/Users
fi

if [ -z "$NEWROOT" ]; then
  NEWROOT="/"
fi

R="$NEWROOT"
mp="/boot"

# command line
for x in $(cat /proc/cmdline); do
  case $x in
  systemd.hostname=*)
    HOST_CMDLINE=${x#systemd.hostname=}
  ;;
  esac
done

echo gombi

# storage
#if [ -d /dev/disk/by-partlabel ]; then
#  EFI=$(cd /dev/disk/by-partlabel/ && ls efi_* 2>/dev/null )
#fi

#if [ -n "$EFI" ]; then
#  HOST_DISK=$(echo $EFI | cut -d_ -f2)
#fi

#rm $R/lib/systemd/system/nfs-blkmap.service

# Find the partition labels (first match)
#HOME_PART=$(cd /dev/disk/by-label/ && ls --color=never home* 2>/dev/null | head -n1)

# cpu
#grep -q ^flags.*\ hypervisor /proc/cpuinfo && HOST_CPU="vm"

#cpu=$(grep "model name" -m1 /proc/cpuinfo)

#if [ -z "$HOST_CPU" ]; then
#  case "$cpu" in
#    *E5-2670*)
#      HOST_CPU="bestia"
#    ;;
#    *i7-3630QM*)
#      HOST_CPU="np700g"
#    ;;
#    *i7-4870HQ*)
#      HOST_CPU="taska"
#    ;;
#  esac
#fi

# Set host based on priorities
if [ -n "$HOST_CMDLINE" ]; then
  HOST="$HOST_CMDLINE"
elif [ -n "$HOST_DISK" ]; then
  HOST="$HOST_DISK"
elif [ -n "$HOST_CPU" ]; then
 HOST="$HOST_CPU"
fi

# Per-host configuration is optional
if [ -d "$mp/config" ]; then
  cd $mp/config
  # Per instance configuration file
  . ./rootfs-*.cfg
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

[ -n "$HOST" ] && echo "$HOST" > $R/etc/hostname

[ -n "$HOST" ] && echo "127.0.0.1 $HOST" >> $R/etc/hosts
[ -n "$IP" ] && echo "192.168.1.$IP $HOST" >> $R/etc/hosts

# DHCP
if [ -f "dhcp.conf" ]; then
  cp dhcp.conf $R/etc/dnsmasq.d/
  chmod 444 $R/etc/dnsmasq.d/dhcp.conf

  echo "127.0.0.1 localhost" > $R/etc/hosts
  cat dhcp.conf | grep ^dhcp-host | mawk 'BEGIN { FS = "," } ; { print $3 " " $2}' >> $R/etc/hosts
  chmod 444 $R/etc/hosts

  ln -sf /lib/systemd/system/dnsmasq.service $R/etc/systemd/system/multi-user.target.wants/dnsmasq.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/systemd-resolved.service
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
#if [ ! -z "$MID" ]; then
#  rm -rf $R/etc/machine-id $R/var/lib/dbus/machine-id 2>/dev/null
#  echo $MID > $R/etc/machine-id
#  mkdir -p $R/var/lib/dbus
#  ln -sf $R/etc/machine-id $R/var/lib/dbus/machine-id
#fi

# sshd host keys
if [ ! -z "$SSHD_KEY" ]; then
  rm -rf $R/etc/ssh/ssh_host_*key* 2>/dev/null
  echo -e $SSHD_KEY > $R/etc/ssh/ssh_host_ed25519_key
  echo $SSHD_KEY_PUB > $R/etc/ssh/ssh_host_ed25519_key.pub
  chmod 400 $R/etc/ssh/ssh_host_ed25519_key*

  #harden sshd
  echo "Port $SSHD_PORT=" >> /run/sshd_kucko.conf
  echo "PasswordAuthentication no" >> /run/sshd_kucko.conf
  chmod 0440 /run/sshd_kucko.conf
  ln -sf ../../../run/sshd_kucko.conf $R/etc/ssh/sshd_config.d
fi

# configure vmware service
if [ -d "vmware" ]; then
  mkdir -p /home/vm
  ln -sf /home/vm/ "$R/var/lib/vmware/Shared VMs"
  mkdir -p $R/var/lib/vmware/
  cp license-* $R/etc/vmware/
  chmod 444 $R/etc/vmware/license-*
  cp vmware/* $R/etc/vmware/hostd/
  sed -i 's/^acceptOVFEULA .*/acceptOVFEULA = "yes"/' $R/etc/vmware/config
  sed -i 's/^acceptEULA .*/acceptEULA = "yes"/' $R/etc/vmware/config
  sed -i 's/^installerDefaults.autoSoftwareUpdateEnabled .*/installerDefaults.autoSoftwareUpdateEnabled = "no"/' $R/etc/vmware/config
  sed -i 's/^installerDefaults.dataCollectionEnabled .*/installerDefaults.dataCollectionEnabled = "no"/' $R/etc/vmware/config
  sed -i 's/^installerDefaults.dataCollectionEnabled.initialized .*/installerDefaults.dataCollectionEnabled.initialized = "yes"/' $R/etc/vmware/config
fi

# Closing the lid on power should not suspend this laptop
#  sed -i 's|\#HandleLidSwitchExternalPower=.*|HandleLidSwitchExternalPower=ignore|g' $R/etc/systemd/logind.conf

# /etc/udev/rules.d
# support my devices
if [ -f "$mp/dotfiles/boot/99-kucko.rules" ]; then
  cp "$mp/dotfiles/boot/99-kucko.rules" /run/99-kucko.rules
  chmod 0440 /run/99-kucko.rules
fi
ln -sf ../../../run/99-kucko.rules $R/etc/udev/rules.d

#touch $R/etc/sudoers.d/sudoers
#chmod 0440 $R/etc/sudoers.d/sudoers

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
  sed -i '/^admin:/d' $R/etc/passwd
  sed -i '/^admin:/d' $R/etc/shadow
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
  sed -i '/^admin:/d' $R/etc/passwd
  sed -i '/^admin:/d' $R/etc/shadow
fi

# fstab
#if [ -n "$HOME_PART" ]; then
#  mkdir -p /home
#  echo "LABEL=$HOME_PART /home auto noauto,x-systemd.automount,x-systemd.idle-timeout=5min 0 2" >> $R/etc/fstab
#  ln -sf /home $R/Users
#fi

# used if live booting from iso
if [ -f "/run/initramfs/live/nixfile" ]; then
  mkdir -p /nix
#  echo '/run/initramfs/live/nixfile /nix squashfs noauto,x-systemd.automount,x-systemd.idle-timeout=5min 0 2' >> $R/etc/fstab
  mount /run/initramfs/live/nixfile /nix
fi

#mkdir -p /run/media/modules

# todo - readonly porbably does not make a difference
# This will consume about an extra 10 M RAM
# Maybe using an ext4 or squashfs with /dev/ram0 root would save that 10 MB

#echo '/run/media/efi/kernel/modules.img /run/media/modules fuse.archivemount ro,nofail,readonly 0 2' >> $R/etc/fstab
#echo '/run/media/efi/kernel/modules.img /run/media/modules fuse.archivefs nofail,x-systemd.wanted-by=systemd-udevd.service,x-systemd.before=sysinit.target 0 0' >> $R/etc/fstab

#ln -sf /run/media/modules/usr/lib/modules $R/usr/lib/

# --- HOST specific logic

# install all service files
if [ -d "$mp/config" ]; then
  FILES="*.service"
  if [ $FILES != '*.service' ]; then
    for f in *.service; do
      cp $f $R/etc/systemd/system/
      chmod 444 $R/etc/systemd/system/$f
      ln -sf /etc/systemd/system/$f $R/etc/systemd/system/multi-user.target.wants/$f
    done
  fi
fi

if [ "$HOST" == "pincer" ]; then
  # make it easy to deploy new rootfs
  echo '%sudo ALL=NOPASSWD:/bin/btrfs' >> $R/etc/sudoers.d/sudoers

  # Patch apcupsd config to connect it via usb
  sed -i "s|^DEVICE.*|DEVICE|g" $R/etc/apcupsd/apcupsd.conf
  ln -sf /lib/systemd/system/apcupsd.service $R/etc/systemd/system/multi-user.target.wants/apcupsd.service

  BESTIA=$(cat dhcp.conf | grep ,bestia | cut -d, -f1 | cut -d= -f2)
  echo "wakeonlan $BESTIA" > $R/usr/bin/wake-bestia
  chmod 555 $R/usr/bin/wake-bestia

  # cron
  ln -sf /lib/systemd/system/cron.service $R/etc/systemd/system/multi-user.target.wants/cron.service

  # NFS
  #echo 'run/media/linux/linux *(no_subtree_check,no_root_squash) ' >> $R/etc/exports
  #ln -sf /lib/systemd/system/rpcbind.service $R/etc/systemd/system/multi-user.target.wants/rpcbind.service
  #ln -sf /lib/systemd/system/nfs-server.service $R/etc/systemd/system/multi-user.target.wants/nfs-server.service
fi

if [ "$HOST" == "bestia" ]; then
  echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> $R/etc/sudoers.d/sudoers

#  echo '/home/nix /nix auto bind,noauto,x-systemd.automount,x-systemd.idle-timeout=5min 0 2' >> $R/etc/fstab
  mkdir -p /nix
#  echo 'LABEL=linux /nix btrfs subvol=usrlocal 0 2' >> $R/etc/fstab
  mount -o subvol=usrlocal /dev/disk/by-label/linux /nix

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

  # autosuspend
  if [ -f "$mp/dotfiles/boot/autosuspend.conf" ]; then
    cp "$mp/dotfiles/boot/autosuspend.conf" $R/etc/autosuspend.conf
    ln -sf /lib/systemd/system/autosuspend.service $R/etc/systemd/system/multi-user.target.wants/autosuspend.service
    if [ -f "$mp/dotfiles/boot/active.ics" ]; then
      cp "$mp/dotfiles/boot/active.ics" /run/
    fi
  fi

fi

# nix
if [ "$HOST" == "bestia" ] || [ -f "/run/initramfs/live/nixfile" ]; then
  mkdir -p $R/nix
  rm -rf $R/usr/local
  ln -sf /nix/var/nix/profiles/default $R/usr/local
  ln -sf /nix/var/nix/profiles/default $R/root/.nix-profile

  echo "nixbld:x:503:503::/nonexistent:/bin/sh" >> $R/etc/passwd
  echo "nixbld:!:18916:0:99999:7:::" >> $R/etc/shadow
  echo "nixbld:!::nixbld" >> $R/etc/gshadow
  echo "nixbld:x:503:nixbld" >> $R/etc/group
fi

# server profile

# Persistent container storage for docker
if [ "$HOST" == "bestia" ] ; then
  mkdir -p /var/lib/docker
#  echo 'LABEL=linux /var/lib/docker btrfs subvol=containers 0 2' >> $R/etc/fstab
  mount /dev/disk/by-label/linux -o subvol=containers /var/lib/docker
fi

if [ "$HOST" == "pincer" ]; then
  ln -sf /home/containers $R/var/lib/docker
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
  mkdir -p /run/media/letsencrypt
  cp -r /run/media/efi/config/letsencrypt /run/media/

 if [ -f "nginx.conf" ]; then
   cp nginx.conf $R/etc/nginx/
 fi
fi

if [ "$HOST" == "linux" ]; then
  echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> $R/etc/sudoers.d/sudoers

  # Autologin
  sed -i "s|\#\ autologin=.*|autologin=admin|g" $R/etc/lxdm/lxdm.conf

  # sudo permission for all terminal sessions instead of per terminal - this is a privilege esculation vulnability
  # echo 'Defaults  !tty_tickets' >> $R/etc/sudoers.d/sudoers
fi

if [ "$HOST" == "vm" ]; then
  echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> $R/etc/sudoers.d/sudoers

  # Autologin
  sed -i "s|\#\ autologin=.*|autologin=admin|g" $R/etc/lxdm/lxdm.conf

  # Mount home directories from the host at boot
  mkdir -p /home/host
#  echo '.host:/bagoly /home fuse.vmhgfs-fuse defaults,allow_other,uid=99,gid=27,nosuid,nodev,nonempty 0 0' >> $R/etc/fstab
#  echo '.host:/home /home/host fuse.vmhgfs-fuse defaults,allow_other,uid=99,gid=27,nosuid,nodev,nonempty 0 0' >> $R/etc/fstab
  mount -t fuse.vmhgfs-fuse -o defaults,allow_other,uid=99,gid=27,nosuid,nodev,nonempty .host:/bagoly /home
  mount -t fuse.vmhgfs-fuse -o defaults,allow_other,uid=99,gid=27,nosuid,nodev,nonempty .host:/home /home/host
fi

#systemctl daemon-reload