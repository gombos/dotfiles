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

# Add efi partition
sudo sgdisk -n 0:0:+${EFISIZE}M  -t 0:ef00 -c 0:"efi_linux" $DISK
sudo partprobe $DISK
sudo mkfs.vfat -F 32 -n EFI -i 10000000 ${DISK}p1 || fail "cannot create efi"
sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"

if [ -z $2 ]; then
  infra-get-efi.sh
  sudo rsync -r /tmp/efi/efi/ $MNT_EFI
else
  sudo rsync -r $2 $MNT_EFI
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

mkdir /tmp/iso/
sudo rsync -av $MNT_EFI/ /tmp/iso/

sudo umount $MNT_EFI
sudo losetup -d $DISK

sudo losetup $DISK $FILE
sudo partprobe $DISK

sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"
sudo umount $MNT_EFI

#sudo sgdisk -n 0:0: -t 0:8304 -c 0:"linux_linux" $DISK

#sudo partprobe $DISK

#echo "Creating filesystems..."
#sudo mkfs.btrfs -L "linux" -U 10000000-0000-0000-0000-000000000000 ${DISK}p2 || fail "cannot create root"

#sudo mount -o compress=zstd ${DISK}p2 $MNT || fail "cannot mount"
#sudo chmod g+w  $MNT
#sudo btrfs subvolume create $MNT/linux
#sudo chmod g+w  $MNT/linux

#cd $MNT/linux
#sudo btrfs subvolume set-default .

#if [ -z $3 ]; then
#  infra-get-rootfs.sh $MNT/linux
#else
#  sudo rsync -av $3 $MNT/linux/
#fi

# Make it read-only
#sudo btrfs property set -ts $MNT/linux ro true
#cd /

# rootfs squashfs
sudo mkdir -p /tmp/iso/LiveOS
#sudo mksquashfs $MNT/linux/ /tmp/iso/LiveOS/squashfs.img

infra-get-squash.sh
sudo mv /tmp/squashfs/tmp/squashfs.img /tmp/iso/LiveOS/squashfs.img

sudo mksquashfs /nix /tmp/iso/nixfile

cd /tmp/iso
sudo chown -R 1000:1000  .
#cp EFI/BOOT/bootx64.efi isolinux/
#cp ~/b/efiboot.img  isolinux/
#mv isolinux/bios.img  /tmp/

touch isolinux/efiboot.img
touch isolinux/bootx64.efi

xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "kucko" \
   -eltorito-boot boot/grub/bios.img \
   -no-emul-boot \
   -boot-load-size 4 \
   -boot-info-table \
   --eltorito-catalog boot/grub/boot.cat \
   --grub2-boot-info \
   --grub2-mbr /tmp/iso/isolinux/boot_hybrid.img \
   -eltorito-alt-boot \
   -e EFI/efiboot.img \
   -no-emul-boot \
   -append_partition 2 0xef isolinux/efiboot.img \
   -output "/tmp/kucko.iso" \
   -graft-points \
      "." \
      /boot/grub/bios.img=isolinux/bios.img \
      /EFI/efiboot.img=isolinux/efiboot.img

# iso
#genisoimage -v -J -r -V kucko -o /tmp/kucko.iso /tmp/iso/

#sudo umount $MNT
sudo losetup -d $DISK
sudo rm -rf $MNT $MNT_EFI $MNT_DIR
sudo rm -rf /tmp/efi /tmp/iso/
