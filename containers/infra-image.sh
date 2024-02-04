#!/bin/bash

#echo 'deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' >> /etc/apt/sources.list
#echo 'deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware' >> /etc/apt/sources.list
#echo 'deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' >> /etc/apt/sources.list

mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial /var/lib/dpkg/
touch /var/lib/dpkg/lock-frontend

echo 'deb https://deb.debian.org/debian bookworm-backports main' >> /etc/apt/sources.list

cat /etc/apt/sources.list

apt-get update -y -qq && apt-get upgrade -y -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -t bookworm-backports --no-install-recommends -o Dpkg::Use-Pty=0 xorriso systemd-boot-efi mtools binutils systemd
#intel-microcode

dpkg -l | grep systemd

ls -la /usr/lib/systemd/ukify
ukify
which ukify

OUT_DIR=${OUT_DIR:=/tmp}

mv /iso /tmp/
mv /efi/* /tmp/iso/
mkdir -p /tmp/iso/LiveOS /tmp/iso/kernel /tmp/iso/extensions
mv /tmp/iso/squashfs.img /tmp/iso/LiveOS/
mv /tmp/iso/sysext.raw   /tmp/iso/extensions/
mv /boot/vmlinuz-* /tmp/iso/kernel/

cp /_tmp/boot/grub.cfg /tmp/iso/EFI/BOOT/

cd /tmp/iso

rm -rf syslinux

# Only include files once in the iso
mkdir /tmp/isotemp

mv isolinux/bios.img /tmp/isotemp/
mv isolinux/efiboot.img /tmp/isotemp/

# support BIOS and UEFI
cd kernel && ln -sf vmlinuz-* vmlinuz && cd ..

find .
chown -R 0:0 .
chmod +x LiveOS kernel extensions
ln -sf kernel

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

# make unified kernel

#/usr/lib/systemd/ukify build

ukify build \
  --linux=/tmp/iso/kernel/vmlinuz \
  --initrd=/tmp/iso/kernel/initrd.img \
  --cmdline='console=ttyS0' \
  --output=/tmp/iso/EFI/BOOT/BOOTX64.efi

#echo "console=ttyS0" > /tmp/cmdline
#objcopy --verbose  \
#    --add-section .osrel="/etc/os-release" --change-section-vma .osrel=0x20000 \
#    --add-section .cmdline="/tmp/cmdline" --change-section-vma .cmdline=0x30000 \
#    --add-section .linux="/tmp/iso/kernel/vmlinuz" --change-section-vma .linux=0x40000 \
#    --add-section .initrd="/tmp/iso/kernel/initrd.img" --change-section-vma .initrd=0x3000000 \
#    /usr/lib/systemd/boot/efi/linuxx64.efi.stub /tmp/iso/EFI/BOOT/BOOTX64.efi

## experiment for minimal iso
rm -rf extensions

## todo - calculate size/count
dd if=/dev/zero of=/tmp/efiboot.img bs=1M count=12
mkfs.vfat /tmp/efiboot.img
LC_CTYPE=C mmd -i /tmp/efiboot.img EFI EFI/BOOT
LC_CTYPE=C mcopy -i /tmp/efiboot.img /tmp/iso/EFI/BOOT/BOOTX64.efi ::EFI/BOOT/
rm -rf boot efi isolinux kernel EFI syslinux

ls -lRah /tmp/iso

xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "ISO" \
   -output "/tmp/linux-core.iso" \
   -eltorito-alt-boot \
     -e EFI/efiboot.img \
     -no-emul-boot \
   -graft-points \
      "." \
      /EFI/efiboot.img=/tmp/efiboot.img

# log the size
ls -lha /tmp/*.iso

rm -rf /tmp/iso
rm -rf /boot
