#!/bin/bash

# $1 - targets
# - all (default) - hybrid mbr
# - vm - optimized for a small vm image, gpt boot only

# $2 - efi directory if exists
# $3 - rootfs directory if exists

find /iso
ls -lRa /iso

exit


if ! [ -z "$REPO" ]; then
  cp $REPO/bin/* /tmp/
  cd /tmp
fi

OUT_DIR=${OUT_DIR:=/tmp}
MNT_DIR=${MNT_DIR:=$OUT_DIR/mnt}
MNT=$MNT_DIR/root
MNT_EFI=$MNT_DIR/efi

rm -rf $MNT $MNT_EFI $MNT_DIR

mkdir -p $MNT $MNT_EFI

mkdir /tmp/iso/

if [ -z $2 ]; then
  infra-get-efi.sh
  rsync -r /tmp/efi/ /tmp/iso
else
  rsync -r $2 /tmp/iso
fi

ls -la /tmp/efi/kernel
ls -la /tmp/iso/kernel

# rootfs squashfs
#infra-get-squash.sh
mkdir -p /tmp/iso/LiveOS

rm -rf /tmp/laptop
mkdir -p /tmp/laptop
infra-get-rootfs.sh /tmp/laptop
mksquashfs /tmp/laptop/lib/firmware /tmp/iso/kernel/firmware -comp zstd
rm -rf /tmp/laptop/lib/firmware

mksquashfs /tmp/laptop /tmp/iso/LiveOS/squashfs.img -comp zstd
rm -rf /tmp/laptop

ls -la /tmp/iso/kernel

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

mount $DISK $MNT_EFI

cd $MNT_EFI
git clone https://github.com/gombos/dotfiles.git .dotfiles
cp .dotfiles/boot/grub.cfg /tmp/iso/EFI/BOOT/
HOME=$MNT_EFI .dotfiles/bin/infra-provision-user.sh
chown -R 99:4 .
cd /
umount $MNT_EFI

cd /tmp/iso

# keep iso under 2GB
#sudo wget --quiet https://github.com/gombos/dotfiles/releases/download/usrlocal/usrlocal.img -O /tmp/iso/usrlocal.img
cp /tmp/usrlocal.img /tmp/iso/usrlocal.img
chown -R 1000:1000 .

# Only include files once in the iso
mkdir /tmp/isotemp
mv isolinux/bios.img /tmp/isotemp/
mv isolinux/efiboot.img /tmp/isotemp/

find /tmp/iso

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
rm -rf $MNT $MNT_EFI $MNT_DIR
rm -rf /tmp/efi /tmp/iso /tmp/isotemp
