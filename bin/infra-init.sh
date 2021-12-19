#!/bin/bash

mkdir -p /run/media
chown 0:27 /run/media
chmod g+w /run/media

# todo - implement command line argument to disable running this script in initrd
# todo - split this into etc/fstab generator and into a an init systemd rc.local script that can be executed without reexecuting initrd

# initramfs
# mount modules from ESP
# populate /etc/fstab

if [[ -e /dev/disk/by-label/EFI ]]; then
  mkdir -p /run/media/efi
  mount -o ro,noexec,nosuid,nodev /dev/disk/by-label/EFI /run/media/efi
  mp=/run/media/efi
fi

if [[ -e /dev/disk/by-label/ISO ]]; then
  mp=/run/initramfs/live
fi

# Make the modules available to boot
mkdir -p $NEWROOT/usr/lib/modules
mount $mp/kernel/modules $NEWROOT/usr/lib/modules

# Make the kernel available for kexec
mkdir -p $NEWROOT/boot
mount --bind $mp/kernel $NEWROOT/boot

# Allow for config to be on different drive than the rest of the boot files
RDEXEC=/run/media/efi/config/infra-boots.sh
for x in $(cat /proc/cmdline); do
 case $x in
  rd.exec=*)
    RDEXEC=${x#rd.exec=}
  ;;
  esac
done

if [ -f "$RDEXEC" ]; then
  # Execute the rd.exec script in a sub-shell
  printf "[rd.exec] start executing $RDEXEC \n"
  scriptname="${RDEXEC##*/}"
  scriptpath=${RDEXEC%/*}
  configdir="$scriptpath"
  ( cd $configdir && . "./$scriptname" )
  printf "[rd.exec] stop executing $RDEXEC \n"
fi

if [ -f /run/media/efi/config/grub.cfg ]; then
  mount -o remount,rw /run/media/efi
  rm /run/media/efi/config/grub.cfg
  mount -o remount,ro /run/media/efi
fi
