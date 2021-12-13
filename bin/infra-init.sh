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

mkdir -p $NEWROOT/boot
mount --bind $mp/kernel $NEWROOT/boot
mkdir -p $NEWROOT/usr/lib/modules
mount $mp/kernel/modules $NEWROOT/usr/lib/modules

# todo - execute all sceipt, remove the srip name from here
if [[ -e /run/media/efi/config/infra-boots.sh ]]; then
  cd /run/media/efi/config
  ( . ./infra-boots.sh )
fi
