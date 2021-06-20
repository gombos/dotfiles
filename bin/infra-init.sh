# first boot of a new instance, run all the “per-instance” configuration

# Warning: error in this file will likely lead to failure to boot
# Consider only testing/changing this file in a development environment with access to console

# This script logs to /run/initramfs/rdexec.out
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

R="$NEWROOT"

# --- detect the environment

# command line
for x in $(cat /proc/cmdline); do
  case $x in
  systemd.hostname=*)
    HOST_CMDLINE=${x#systemd.hostname=}
  ;;
  esac
done

# storage
EFI=$(cd /dev/disk/by-partlabel/ && ls efi_*)

if [ -n "$EFI" ]; then
  HOST_DISK=$(echo $EFI | cut -d_ -f2)
fi

# Find the partition labels (first match)
HOME_PART=$(cd /dev/disk/by-label/ && ls --color=never home* | head -n1)
SWAP_PART=$(cd /dev/disk/by-label/ && ls --color=never swap* | head -n1)
LINUX_PART=$(cd /dev/disk/by-label/ && ls --color=never linux* | head -n1)

# cpu
grep -q ^flags.*\ hypervisor /proc/cpuinfo && HOST_CPU="vm"

cpu=$(grep "model name" -m1 /proc/cpuinfo)

if [ -z "$HOST_CPU" ]; then
  case "$cpu" in
    *E5-2670*)
      HOST_CPU="bestia"
    ;;
    *i7-3630QM*)
      HOST_CPU="np700g"
    ;;
    *i7-4870HQ*)
      HOST_CPU="taska"
    ;;
  esac
fi

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

mkdir -p /run/media
chown 0:27 /run/media
chmod g+w /run/media

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
  cat dhcp.conf | grep ^dhcp-host | awk 'BEGIN { FS = "," } ; { print $3 " " $2}' >> $R/etc/hosts
  chmod 444 $R/etc/hosts

  ln -sf /lib/systemd/system/dnsmasq.service $R/etc/systemd/system/multi-user.target.wants/dnsmasq.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/systemd-resolved.service
  rm -rf $R/etc/resolv.conf
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
  mkdir -p $R/var/lib/dbus
  ln -sf $R/etc/machine-id $R/var/lib/dbus/machine-id
fi

# sshd host keys
if [ ! -z "$SSHD_KEY" ]; then
  rm -rf $R/etc/ssh/ssh_host_*key* 2>/dev/null
  echo -e $SSHD_KEY > $R/etc/ssh/ssh_host_ed25519_key
  echo $SSHD_KEY_PUB > $R/etc/ssh/ssh_host_ed25519_key.pub
  chmod 400 $R/etc/ssh/ssh_host_ed25519_key*
fi

sed -i "s|bottom_pane=.*|bottom_pane=0|g" $R/etc/lxdm/lxdm.conf

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

# Todo - make static IP configurable - maybe grub menu or grub option
#  sed -i "s|\#\ autologin=.*|autologin=henrik|g" $R/etc/lxdm/lxdm.conf
# Closing the lid on power should not suspend this laptop
#  sed -i 's|\#HandleLidSwitchExternalPower=.*|HandleLidSwitchExternalPower=ignore|g' $R/etc/systemd/logind.conf

# /etc/udev/rules.d
# support my devices
if [ -f "$mp/dotfiles/boot/99-kucko.rules" ]; then
  cp "$mp/dotfiles/boot/99-kucko.rules" /run/99-kucko.rules
  chmod 0440 /run/99-kucko.rules
fi
ln -sf ../../../run/99-kucko.rules $R/etc/udev/rules.d

# harden sshd
echo "Port $SSHD_PORT=" >> /run/sshd_kucko.conf
echo "PasswordAuthentication no" >> /run/sshd_kucko.conf
chmod 0440 /run/sshd_kucko.conf
ln -sf ../../../run/sshd_kucko.conf $R/etc/ssh/sshd_config.d

# allow some executables to run without sudo password
# sensitive data should be all protected with additional encryption password at rest
echo '%sudo ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount, /usr/sbin/cryptsetup' >> /run/sudoers_kucko

# make it easy to deploy new rootfs
echo '%sudo ALL=NOPASSWD:/bin/btrfs' >> /run/sudoers_kucko
echo '%sudo ALL=NOPASSWD:/usr/sbin/reboot' >> /run/sudoers_kucko
chmod 0440 /run/sudoers_kucko

ln -sf ../../run/sudoers_kucko $R/etc/sudoers.d

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

# bagoly user
if [ ! -z "$BAGOLYPWD" ]
then
  echo "bagoly:x:1002:1002:,,,:/home/bagoly:/bin/bash" >> $R/etc/passwd
  echo "bagoly:$BAGOLYPWD:1:0:99999:7:::" >> $R/etc/shadow
  echo "bagoly:!::" >> $R/etc/gshadow
  echo "bagoly:x:1002:" >> $R/etc/group
  sed -i "s/^sudo:.*/&,bagoly/" $R/etc/group
  sed -i "s/^users:.*/&,bagoly/" $R/etc/group

  # remove the admin user
  sed -i '/^admin:/d' $R/etc/passwd
  sed -i '/^admin:/d' $R/etc/shadow
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
if [ -n "$HOME_PART" ]; then
  mkdir -p /home
  echo "LABEL=$HOME_PART /home auto noauto,x-systemd.automount,x-systemd.idle-timeout=5min 0 2" >> $R/etc/fstab
  ln -sf /home $R/Users
fi

if [ -n "$SWAP_PART" ]; then
  echo "LABEL=$SWAP_PART none swap nofail,x-systemd.device-timeout=5 0 0" >> $R/etc/fstab
fi

if [ -n "$LINUX_PART" ]; then
  echo "LABEL=$LINUX_PART /run/media/linux btrfs noauto,x-systemd.automount,x-systemd.idle-timeout=5min,subvol=/ 0 2" >> $R/etc/fstab
fi

if [ -d "$mp/modules" ]; then
  # Restrict only root process to load kernel modules. This is a reasonable system hardening

  if [ -d $R/lib/modules ]; then
    mv $R/lib/modules $R/lib/modules.root
  fi

  ln -sf /run/media/efi/modules $R/lib/

  mkdir -p /run/media/efi
  echo 'LABEL=EFI /run/media/efi auto ro,noexec,nosuid,nodev,umask=0077 0 0' >> $R/etc/fstab
fi

# --- HOST specific logic

if [ "$HOST" == "pincer" ]; then
  echo "nomodeset systemd.unit=multi-user.target" >> /etc/cmdline.d/90-console.conf

  # Patch apcupsd config to connect it via usb
  sed -i "s|^DEVICE.*|DEVICE|g" $R/etc/apcupsd/apcupsd.conf
  ln -sf /lib/systemd/system/apcupsd.service $R/etc/systemd/system/multi-user.target.wants/apcupsd.service

  # papertrail
  cp papertrail.service $R/etc/systemd/system/
  chmod 444 $R/etc/systemd/system/papertrail.service
  ln -sf /etc/systemd/system/papertrail.service $R/etc/systemd/system/multi-user.target.wants/papertrail.service

  # disable dunst
  rm $R/etc/systemd/user/default.target.wants/dunst.service

  # disable pulseaudio
  rm $R/etc/init.d/pulseaudio-enable-autospawn $R/etc/systemd/user/default.target.wants/pulseaudio.service $R/etc/systemd/user/sockets.target.wants/pulseaudio.socket

  BESTIA=$(cat dhcp.conf | grep ,bestia | cut -d, -f1 | cut -d= -f2)
  echo "wakeonlan $BESTIA" > $R/usr/bin/wake-bestia
  chmod 555 $R/usr/bin/wake-bestia

  # cron
  ln -sf /lib/systemd/system/cron.service $R/etc/systemd/system/multi-user.target.wants/cron.service

  # NFS
  echo 'run/media/linux/linux *(no_subtree_check,no_root_squash) ' >> $R/etc/exports
  ln -sf /lib/systemd/system/rpcbind.service $R/etc/systemd/system/multi-user.target.wants/rpcbind.service
  ln -sf /lib/systemd/system/nfs-server.service $R/etc/systemd/system/multi-user.target.wants/nfs-server.service

  # Mask services not required on pincer
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/dmesg.service
  ln -sf /dev/null $R/etc/systemd/system/bluetooth.target.wants/bluetooth.service
  ln -sf /dev/null $R/etc/systemd/system/getty.target.wants/getty@tty1.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/NetworkManager.service
  ln -sf /dev/null $R/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/rsyslog.service
fi

if [ "$HOST" == "bestia" ]; then
  # nvidia driver
  echo nvidia >> $R/etc/modules

  # motherboard sensors Nuvoton W83677HG-I (NCT6776)
  echo w83627ehf >> $R/etc/modules

  mkdir -p $R/nix

  echo '/home/nix /nix auto bind,noauto,x-systemd.automount,x-systemd.idle-timeout=5min 0 2' >> $R/etc/fstab

  sed -i 's|\#user_allow_other|user_allow_other|g' $R/etc/fuse.conf

  # Do not bind the backup ssd by default at boot
  # This is only safe to do if not booting from this drive
  # TODO - implement safe condition
  #echo offline > /sys/block/sdb/device/state
  #echo 1 > /sys/block/sdb/device/delete

  # Power button should suspend instead of poweroff
  sed -i 's|\#HandlePowerKey=.*|HandlePowerKey=suspend|g' $R/etc/systemd/logind.conf

  # IMAP
  #echo "$HOST" > $R/etc/mailname
  #sed -i 's|\#port.*993|port=993\n    ssl=yes|g' $R/etc/dovecot/conf.d/10-master.conf
  #sed -i 's|mail_location.*|mail_location = maildir:~/Maildir:LAYOUT=fs|g' $R/etc/dovecot/conf.d/10-mail.conf

  # Only ask for sudo password once in a day
  echo 'Defaults timestamp_timeout=1440' >> /run/sudoers_kucko

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
if [ "$HOST" == "pincer" ] || [ "$HOST" == "bestia" ] ; then
  # machinectl
#  mkdir -p $R/var/lib/machines/lab
#  echo '/live/image /var/lib/machines/lab none defaults,bind 0 0' >> $R/etc/fstab

  # portablectl
#  mkdir -p $R/var/lib/portables/lab
#  echo '/live/image /var/lib/portables/lab none defaults,bind 0 0' >> $R/etc/fstab

  # Persistent container storage for docker
  ln -sf /home/containers $R/var/lib/docker
  ln -sf /lib/systemd/system/docker.service $R/etc/systemd/system/multi-user.target.wants/docker.service
fi

if [ "$HOST" == "vm" ]; then
  sed -i '/^admin:/d' $R/etc/passwd
  echo "admin:x:99:0:,,,:/home/bagoly:/bin/bash" >> $R/etc/passwd

  # Mount home directories from the host at boot
  mkdir -p /home/bagoly
  echo '.host:/home /home fuse.vmhgfs-fuse defaults,allow_other,uid=99,gid=27,nosuid,nodev,nonempty 0 0' >> $R/etc/fstab
  echo '.host:/bagoly /home/bagoly fuse.vmhgfs-fuse defaults,allow_other,uid=99,gid=27,nosuid,nodev,nonempty 0 0' >> $R/etc/fstab

  # Mask services not required inside a vm
  ln -sf /dev/null $R/etc/systemd/system/bluetooth.target.wants/bluetooth.service
  ln -sf /dev/null $R/etc/systemd/system/getty.target.wants/getty@tty1.service
  ln -sf /dev/null $R/etc/systemd/system/open-vm-tools.service.requires/vgauth.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/smartmontools.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/ssh.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/NetworkManager.service
  ln -sf /dev/null $R/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service

  # These policies are for development only
  # Autologin
  sed -i "s|\#\ autologin=.*|autologin=admin|g" $R/etc/lxdm/lxdm.conf

  # Only ask for sudo password once and not expire
  echo 'Defaults timestamp_timeout=-1' >> /run/sudoers_kucko

  # sudo permission for all terminal sessions - this is a privilege esculation vulnability
  echo 'Defaults  !tty_tickets' >> /run/sudoers_kucko
fi
