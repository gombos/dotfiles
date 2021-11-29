#!/bin/bash

ls -la /dev/disk/by-label/

# mount modules
mkdir -p /run/media/efi
rm -rf /usr/lib/modules
mkdir -p /run/media/efi /usr/lib/modules

if [[ -e /dev/disk/by-label/EFI ]]; then
  mount -o ro,noexec,nosuid,nodev /dev/disk/by-label/EFI /run/media/efi
fi

if [[ -e /dev/disk/by-label/ISO ]]; then
  mount -o ro,noexec,nosuid,nodev /dev/disk/by-label/ISO /run/media/efi
fi

ls -la /run/media/efi

mount -o ro /run/media/efi/kernel/modules /usr/lib/modules

modprobe autofs4
modprobe btrfs
modprobe overlayfs

cp /usr/bin/kmod /usr/bin/lsmod

/usr/bin/lsmod

