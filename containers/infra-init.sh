#!/bin/sh

mkdir -p /run/media
chown 0:27 /run/media
chmod g+w /run/media

# todo - implement command line argument to disable running this script in initrd
# todo - split this into etc/fstab generator and into a an init systemd rc.local script that can be executed without reexecuting initrd

# initramfs
# mount modules from ESP
# populate /etc/fstab

# todo
# maybe instead of hardcoding the label, have a deterministi logic as default
# e.g on linode there is actually only one directory under /dev/disk/by-label

if [ -e /dev/disk/by-label/EFI ]; then
  mkdir -p /run/media/efi
  mount -o ro,noexec,nosuid,nodev /dev/disk/by-label/EFI /run/media/efi
fi

if [ -e /dev/disk/by-label/ISO ]; then
  mp=/run/initramfs/live
fi

# Make the modules available to boot
if [ -f "$mp/kernel/modules"  ]; then
  mkdir -p "$NEWROOT/lib/modules"
  mount "$mp/kernel/modules" "$NEWROOT/lib/modules"
fi

# Make the firmware available to boot
if [ -f "$mp/kernel/firmware"  ]; then
  mkdir -p "$NEWROOT/lib/firmware"
  mount "$mp/kernel/firmware" "$NEWROOT/lib/firmware"
fi

# Make the kernel available for kexec
mkdir -p "$NEWROOT/boot"
mount --bind "$mp/kernel" "$NEWROOT/boot"

# Allow for config to be on different drive than the rest of the boot files
if [ -e /run/initramfs/isoscan/config ]; then
  RDEXEC=/run/initramfs/isoscan/config/infra-boots.sh
else
  RDEXEC=/run/media/efi/config/infra-boots.sh
fi

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
