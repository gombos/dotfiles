#!/bin/bash

# $1 - targets
# - all (default) - hybrid mbr
# - vm - optimized for a small vm image, gpt boot only

# $2 - efi directory if exists
# $3 - rootfs directory if exists

if [ -z "$1" ]; then
  TARGET="all"
else
  TARGET="$1"
fi

FILENAME=linux.img
OUT_DIR=${OUT_DIR:=/tmp}
FILE=$OUT_DIR/${FILENAME}
MNT_DIR=${MNT_DIR:=$OUT_DIR/mnt}
MNT=$MNT_DIR/root
MNT_EFI=$MNT_DIR/efi

sudo rm -rf $MNT $MNT_EFI $MNT_DIR

mkdir -p $MNT $MNT_EFI
echo "Installing $RELEASE into $FILE..."

# 3GB image file to fit comfortable to 8 GB sticks or larger
IMGSIZE=${IMGSIZE:=3072} # in megabytes
EFISIZE=${EFISIZE:=300} # in megabytes
MODSIZE=${MODSIZE:=180} # in megabytes

if [ -f $FILE ]; then
  sudo rm -rf $FILE
fi

if [ ! -f $FILE ]; then
  echo "Creating $FILE"
  sudo dd if=/dev/zero of=$FILE bs=1024k seek=${IMGSIZE} count=0
fi

# Find an empty loopback device
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

# Partition device
echo "Partitioning $DISK..."

# format as GPT
# See also https://systemd.io/DISCOVERABLE_PARTITIONS/
# https://wiki.archlinux.org/title/GPT_fdisk
sudo sgdisk -Z $DISK

# Todo make this hybrid instead of gpt so that the image can boot rpi as well
# -h, --hybrid Create a hybrid MBR - three partition numbers max for mbr, boot, os, data
# rpi automatically finds the "first MS-DOS partition on the SD Card" anmd loads bootcode.bin - https://raspberrypi.stackexchange.com/questions/39959/raspbian-boot-process-and-the-partition-table
# firmware looks for the first available MBR fat32 partition.
# https://github.com/pengutronix/genimage/pull/96

# Add efi partition
sudo sgdisk -n 0:0:+${EFISIZE}M  -t 0:ef00 -c 0:"efi_linux" $DISK
sudo partprobe $DISK
sudo mkfs.vfat -F 32 -n EFI -i 10000000 ${DISK}p1 || fail "cannot create efi"
sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"

if [ -z $2 ]; then
  infra-get-efi.sh
  sudo rsync -r --exclude modules /tmp/efi/efi/ $MNT_EFI
else
  sudo rsync -r --exclude modules $2 $MNT_EFI
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
sudo losetup -d $DISK

#Prepare the module file
sudo rm -rf /tmp/modules
sudo dd if=/dev/zero of=/tmp/modules bs=1024k seek=${MODSIZE} count=0
sudo losetup $DISK /tmp/modules
sudo partprobe $DISK
sudo mkfs.btrfs -L "modules" $DISK || fail "cannot create root"
sudo mount -o compress $DISK $MNT || fail "cannot mount"

# First rsync the directory structure only
sudo rsync -a -f"+ */" -f"- *" /tmp/efi/efi/modules/ $MNT

# Copy the large files first to help out the backing store compression
sudo rsync -a /tmp/efi/efi/modules/*/updates/ $MNT/*/updates/

# Copy all files
sudo rsync -a /tmp/efi/efi/modules/ $MNT
sudo umount $MNT
sudo losetup -d $DISK

sudo losetup $DISK $FILE
sudo partprobe $DISK

sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"
sudo cp /tmp/modules $MNT_EFI/kernel/
sudo umount $MNT_EFI

sudo sgdisk -n 0:0: -t 0:8304 -c 0:"linux_linux" $DISK

#if [ "$TARGET" != vm ]; then
#  # make the first 2 partitions visible from mbr as well for rpi
#  sudo sgdisk -h 1,2 $DISK
#fi

sudo partprobe $DISK

echo "Creating filesystems..."
sudo mkfs.btrfs -L "linux" -U 10000000-0000-0000-0000-000000000000 ${DISK}p2 || fail "cannot create root"

sudo mount -o compress=zstd ${DISK}p2 $MNT || fail "cannot mount"
sudo chmod g+w  $MNT
sudo btrfs subvolume create $MNT/linux
sudo chmod g+w  $MNT/linux

cd $MNT/linux
sudo btrfs subvolume set-default .

if [ -z $3 ]; then
  infra-get-rootfs.sh $MNT/linux
else
  sudo rsync -av $3 $MNT/linux/
fi

# Make it read-only
sudo btrfs property set -ts $MNT/linux ro true
cd /

sudo umount $MNT
sudo losetup -d $DISK
sudo rm -rf $MNT $MNT_EFI $MNT_DIR
sudo rm -rf /tmp/modules /tmp/efi
