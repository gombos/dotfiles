#!/bin/sh

# Script executed during ram disk phase (rd.exec = ram disk execute)
. /lib/dracut-lib.sh

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>/run/initramfs/rd.exec.log 2>&1

#mkdir /run/media/efi
#mount -o ro,noexec,nosuid,nodev /dev/sr0  /run/media/efi

# todo - add support loopback mount a file

# EFI label has priority over EFI_* labels
configdrive=""

if [ -L /dev/disk/by-label/EFI ]; then
  configdrive="/dev/disk/by-label/EFI"
else
  for f in /dev/disk/by-label/EFI_*; do
    if [ -z "$configdrive" ]; then
      configdrive="$f"
    fi
  done
fi

for x in $(cat /proc/cmdline); do
  case $x in
  rd.dev=*)
    printf "[rd.dev] $x \n"
    RDDEV=${x#rd.dev=}
    configdrive="/dev/disk/$RDDEV"
    printf "[rd.dev] mount target set to $configdrive\n"
  ;;
  rd.exec=*)
    printf "[rd.exec] $x \n"
    RDEXEC=${x#rd.exec=}
  ;;
  esac
done

# EFI needs to be mounted as early as possible and needs to stay mounted for modules to load properly
mp="/run/media/efi"
mkdir -p "$mp"

drive=$(readlink -f $configdrive)

printf "[rd.exec] Mounting $configdrive = $drive to $mp\n"
mount -o ro,noexec,nosuid,nodev "$drive" "$mp"
printf "[rd.exec] Mounted config\n"

# Restrict only root process to load kernel modules. This is a reasonable system hardening
# todo - mount modules earlier in the dracut lifecycle so that initramfs does not need to include any modules at all
# todo - so build and test dracut with --no-kernel

if [ -f /run/media/efi/kernel/modules ]; then
  mkdir -p /run/media/modules
  printf "[rd.exec] Mounting modules \n"
  mount /run/media/efi/kernel/modules /run/media/modules
  if [ -d $NEWROOT/lib/modules ]; then
    rm -rf $NEWROOT/lib/modules
  fi
  ln -sf /run/media/modules $NEWROOT/lib/
  rm -rf /lib/modules
  ln -sf /run/media/modules /lib/
  printf "[rd.exec] Mounted modules \n"
fi

if [ -f /run/media/efi/kernel/modules.img-fake ]; then
  mkdir -p /run/media/modules
  printf "[rd.exec] Mounting modules \n"
  /usr/bin/archivemount /run/media/efi/kernel/modules.img /run/media/modules -o ro,readonly
  if [ -d $NEWROOT/lib/modules ]; then
    rm -rf $NEWROOT/lib/modules
  fi
  ln -sf /run/media/modules/usr/lib/modules $NEWROOT/usr/lib/
  printf "[rd.exec] Mounted modules \n"
fi

# default init included in the initramfs
if [ -z "$RDEXEC" ]; then
  RDEXEC="/sbin/infra-init.sh"
else
  RDEXEC="$mp/$RDEXEC"
fi

find  /run/media/modules/

printf "[rd.exec] About to run $RDEXEC \n"

if [ -f "$RDEXEC" ]; then
  # Execute the rd.exec script in a sub-shell
  printf "[rd.exec] start executing $RDEXEC \n"
  scriptname="${RDEXEC##*/}"
  scriptpath=${RDEXEC%/*}
  configdir="$scriptpath"
  ( cd $configdir && . "./$scriptname" )
  printf "[rd.exec] stop executing $RDEXEC \n"
fi

exit 0
