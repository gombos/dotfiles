#!/bin/bash

# $1 - efi directory if exists
# $2 - rootfs directory if exists

# $3 - target : all (default), vm, rootfs

if [ -z "$3" ]; then
  TARGET="all"
else
  TARGET="$3"
fi

FILENAME=linux-flat.vmdk
OUT_DIR=${OUT_DIR:=/tmp/img}
FILE=$OUT_DIR/${FILENAME}
MNT_DIR=${MNT_DIR:=$OUT_DIR/mnt}
MNT=$MNT_DIR/root
MNT_EFI=$MNT_DIR/efi

  mkdir -p $MNT $MNT_EFI
  echo "Installing $RELEASE into $FILE..."

  # 3GB image file to fit comfortable to 8 GB sticks or larger
  IMGSIZE=${IMGSIZE:=3072} # in megabytes

  if [ -f $FILE ]; then
    sudo rm -rf $FILE
  fi

  if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    sudo dd if=/dev/zero of=$FILE bs=1024k seek=${IMGSIZE} count=0
  fi

  # Assigning loopback device to the image file
  DISK=""
  for i in /dev/loop* # or /dev/nbd*
  do
    if sudo losetup $i $FILE
    then
      DISK=$i
      break
    fi
  done
  [ "$DISK" == "" ] && fail "no loop device available"

  echo "Connected $FILE to $DISK"

  # Partition device
  echo "Partitioning $DISK..."

  # format as GPT
  # See also https://systemd.io/DISCOVERABLE_PARTITIONS/
  # https://wiki.archlinux.org/title/GPT_fdisk
  sudo sgdisk -Z $DISK

  # Add efi partition
  if [ "$TARGET" != "rootfs" ]; then
    sudo sgdisk -n 0:0:+510M  -t 0:ef00 -c 0:"efi_vm" $DISK
    sudo mkfs.vfat -F 32 -n EFI -i 10000000 ${DISK}p1 || fail "cannot create efi"
    sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"
  fi

  sudo sgdisk -n 0:0:       -t 0:8304 -c 0:"linux_vm" $DISK
  sudo partprobe $DISK

  echo "Creating filesystems..."
  sudo mkfs.btrfs -L "linux" -U 10000000-0000-0000-0000-000000000000 ${DISK}p2 || fail "cannot create root"

  # Todo - test compress
  sudo mount -o compress ${DISK}p2 $MNT || fail "cannot mount"
  sudo chmod g+w  $MNT
  sudo btrfs subvolume create $MNT/linux
  sudo chmod g+w  $MNT/linux

  cd $MNT/linux
  sudo btrfs subvolume set-default .

if [ -z $2 ]; then
  infra-get-rootfs.sh $MNT/linux
else
  sudo rsync -av $2 $MNT/linux/
fi

  # Make it read-only
  sudo btrfs property set -ts $MNT/linux ro true
  cd /
  sudo umount $MNT

if [ -z $1 ]; then
  infra-get-efi.sh
  sudo rsync -r /tmp/efi/efi/ $MNT_EFI
else
  sudo rsync -av $1 $MNT_EFI
fi

  # https://wiki.archlinux.org/title/Syslinux
  sudo sgdisk $DISK --attributes=1:set:2
  sudo dd bs=440 count=1 conv=notrunc if=$MNT_EFI/syslinux/gptmbr.bin of=$DISK
  sudo extlinux --install $MNT_EFI/syslinux/
  cd /

  # directories that are not needed for vm
  if [ "$TARGET" == vm ]; then
    sudo rm -rf $MNT_EFI/syslinux $MNT_EFI/tce
  fi

  sudo umount $MNT_EFI

  sudo losetup -d /dev/loop* 2>/dev/null
