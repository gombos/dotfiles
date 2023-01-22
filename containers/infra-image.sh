#!/bin/bash

OUT_DIR=${OUT_DIR:=/tmp}

find /efi

mv /iso /tmp/
mkdir -p /tmp/iso/LiveOS
mv /tmp/iso/squashfs.img /tmp/iso/LiveOS/
find /tmp/iso

exit

ls -la /tmp/efi/kernel
ls -la /tmp/iso/kernel

rm -rf /tmp/laptop
mkdir -p /tmp/laptop
infra-get-rootfs.sh /tmp/laptop
mksquashfs /tmp/laptop/lib/firmware /tmp/iso/kernel/firmware -comp zstd
rm -rf /tmp/laptop/lib/firmware

ls -la /tmp/iso/kernel

exit

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

rm -rf /tmp/efi /tmp/iso /tmp/isotemp
