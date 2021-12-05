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
else
  mp=/run/initramfs/live
fi

mkdir -p $NEWROOT/boot
mount --bind $mp $NEWROOT/boot
mkdir -p $NEWROOT/usr/lib/modules
mount $mp/kernel/modules $NEWROOT/usr/lib/modules

cd $mp/config
( . ./infra-boots.sh )
