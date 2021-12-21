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

#FILENAME=linux.img
OUT_DIR=${OUT_DIR:=/tmp}
#FILE=$OUT_DIR/${FILENAME}
MNT_DIR=${MNT_DIR:=$OUT_DIR/mnt}
MNT=$MNT_DIR/root
MNT_EFI=$MNT_DIR/efi

sudo rm -rf $MNT $MNT_EFI $MNT_DIR

mkdir -p $MNT $MNT_EFI
#echo "Installing $RELEASE into $FILE..."

# 3GB image file to fit comfortable to 8 GB sticks or larger
#IMGSIZE=${IMGSIZE:=3072} # in megabytes
#EFISIZE=${EFISIZE:=300} # in megabytes
#MODSIZE=${MODSIZE:=180} # in megabytes

#if [ -f $FILE ]; then
#  sudo rm -rf $FILE
#fi

#if [ ! -f $FILE ]; then
#  echo "Creating $FILE"
#  sudo dd if=/dev/zero of=$FILE bs=1024k seek=${IMGSIZE} count=0
#fi

# Find an empty loopback device
#DISK=""
#for i in /dev/loop* # or /dev/nbd*
#do
#  if sudo losetup $i $FILE
#  then
#    DISK=$i
#    break
#  fi
#done
#[ "$DISK" == "" ] && fail "no loop device available"

# Partition device
#echo "Partitioning $DISK..."

# format as GPT
# See also https://systemd.io/DISCOVERABLE_PARTITIONS/
# https://wiki.archlinux.org/title/GPT_fdisk
#sudo sgdisk -Z $DISK

# Add efi partition
#sudo sgdisk -n 0:0:+${EFISIZE}M  -t 0:ef00 -c 0:"efi_linux" $DISK
#sudo partprobe $DISK
#sudo mkfs.vfat -F 32 -n EFI -i 10000000 ${DISK}p1 || fail "cannot create efi"
#sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"

mkdir /tmp/iso/

if [ -z $2 ]; then
  infra-get-efi.sh
  sudo rsync -r /tmp/efi/efi/ /tmp/iso
else
  sudo rsync -r $2 /tmp/iso
fi

# https://wiki.archlinux.org/title/Syslinux
#sudo sgdisk $DISK --attributes=1:set:2
#sudo dd bs=440 count=1 conv=notrunc if=$MNT_EFI/syslinux/gptmbr.bin of=$DISK
#sudo extlinux --install $MNT_EFI/syslinux/
#cd /

# directories that are not needed for vm
#if [ "$TARGET" == vm ]; then
#  sudo rm -rf $MNT_EFI/syslinux $MNT_EFI/tce
#fi

#sudo rsync -av $MNT_EFI/ /tmp/iso/

#sudo umount $MNT_EFI
#sudo losetup -d $DISK

#sudo losetup $DISK $FILE
#sudo partprobe $DISK

#sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"
#sudo umount $MNT_EFI

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
#infra-get-squash.sh
sudo mkdir -p /tmp/iso/LiveOS

sudo rm -rf /tmp/laptop
mkdir -p /tmp/laptop
infra-get-rootfs.sh /tmp/laptop
sudo mksquashfs /tmp/laptop/lib/firmware /tmp/iso/kernel/firmware -comp zstd
sudo rm -rf /tmp/laptop/lib/firmware
sudo mksquashfs /tmp/laptop /tmp/iso/LiveOS/squashfs.img -comp zstd

# home
FILE=/tmp/iso/home.img
dd if=/dev/zero of=$FILE bs=1M count=4
mkfs.ext4 -L "home_iso" $FILE

# Find an empty loopback device
DISK=""
for i in /dev/loop*
do
  if sudo losetup $i $FILE 2>/dev/null
  then
    DISK=$i
    echo $DISK
    break
  fi
done
[ "$DISK" == "" ] && fail "no loop device available"

sudo mount $DISK $MNT_EFI

cd $MNT_EFI
sudo git clone https://github.com/gombos/dotfiles.git .dotfiles
sudo .dotfiles/bin/infra-provision-user.sh
sudo chown -R 99:4 .
cd /
sudo umount $MNT_EFI

cd /tmp/iso

# keep iso under 2GB

# nix
sudo mksquashfs /nix /tmp/iso/nix.img -comp zstd

sudo chown -R 1000:1000 .

# Only include files once in the iso
mkdir /tmp/isotemp
mv isolinux/bios.img /tmp/isotemp/
mv isolinux/efiboot.img /tmp/isotemp/

# todo combine boot and syslinux directories into biosboot directory
# todo rename isolinux to isoboot
# todo rename LiveOS to rootfs
# todo rename BOOT to boot
# todo - is this really needed - /EFI/efiboot.img=../isotemp/efiboot.img , maybe needed for dd

# cp /tmp/iso/LiveOS/squashfs.img /tmp/iso/LiveOS/home.img

# 2nd partition -  0xef - ef EFI (FAT-12/16/
# /tmp/home.img \

# hybrid - ISO can be written bit-for-bit to a USB device to make it a working Live USB

# To mount on MacOS
 # hdiutil attach -nobrowse -nomount linux.iso
 # mount -t cd9660 /dev/disk4 /tmp/cd
 # umount /tmp/cd
 # hdiutil detach /dev/disk4

# Using xorriso on MacOS
  #xorriso -indev linux.iso -osirrox on -extract / linux

# minimal isu config
#sudo rm -rf /tmp/iso/nix.img /tmp/iso/kernel/firmware /tmp/iso/kernel/modules /tmp/iso/home.img

xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "ISO" \
   -output "/tmp/linux.iso" \
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
   -graft-points \
      "." \
      /boot/grub/bios.img=../isotemp/bios.img \
      /EFI/efiboot.img=../isotemp/efiboot.img

#sudo umount $MNT
#sudo losetup -d $DISK
sudo rm -rf $MNT $MNT_EFI $MNT_DIR
sudo rm -rf /tmp/efi /tmp/iso /tmp/isotemp
