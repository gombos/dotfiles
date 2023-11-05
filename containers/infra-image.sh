#!/bin/bash

apt-get update -y -qq && apt-get upgrade -y -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 xorriso systemd-boot-efi mtools

OUT_DIR=${OUT_DIR:=/tmp}

mv /iso /tmp/
mv /efi/* /tmp/iso/
mkdir -p /tmp/iso/LiveOS /tmp/iso/kernel
mv /tmp/iso/squashfs.img /tmp/iso/LiveOS/
cp /boot/vmlinuz* /tmp/vmlinuz_

# netboot-xyz
wget --no-verbose --no-check-certificate https://boot.netboot.xyz/ipxe/netboot.xyz.lkrn
wget --no-verbose --no-check-certificate https://boot.netboot.xyz/ipxe/netboot.xyz.efi
mkdir -p /tmp/iso/efi/netboot
mv netboot.xyz* /tmp/iso/efi/netboot/

echo "rd.live.overlay.overlayfs=1 root=live:/dev/disk/by-label/ISO" > /tmp/cmdline

# make unified kernel
objcopy --verbose  \
    --add-section .osrel="/etc/os-release" --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="/tmp/cmdline" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="/tmp/vmlinuz_" --change-section-vma .linux=0x40000 \
    --add-section .initrd="/tmp/iso/kernel/initrd.img" --change-section-vma .initrd=0x3000000 \
    /usr/lib/systemd/boot/efi/linuxx64.efi.stub /tmp/iso/kernel/vmlinuz

cp /_tmp/boot/grub.cfg /tmp/iso/EFI/BOOT/

cd /tmp/iso
chown -R 1000:1000 .

# Only include files once in the iso
mkdir /tmp/isotemp
mv isolinux/bios.img /tmp/isotemp/
mv isolinux/efiboot.img /tmp/isotemp/

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

rm -rf /tmp/iso
rm -rf /boot

## experiment
#cp kernel/vmlinuz EFI/BOOT/BOOTX64.efi
#
## todo - calculate size/count
#dd if=/dev/zero of=/tmp/efiboot.img bs=1M count=20
#mkfs.vfat /tmp/efiboot.img
#LC_CTYPE=C mmd -i /tmp/efiboot.img EFI EFI/BOOT
#LC_CTYPE=C mcopy -i /tmp/efiboot.img /tmp/iso/EFI/BOOT/BOOTX64.efi ::EFI/BOOT/
#rm -rf boot efi isolinux  kernel EFI syslinux

#find /tmp/iso

#xorriso \
#   -as mkisofs \
#   -iso-level 3 \
#   -full-iso9660-filenames \
#   -volid "ISO" \
#   -output "/tmp/linux.iso" \
#   -eltorito-alt-boot \
#     -e EFI/efiboot.img \
#     -no-emul-boot \
#   -graft-points \
#      "." \
#      /EFI/efiboot.img=/tmp/efiboot.img
