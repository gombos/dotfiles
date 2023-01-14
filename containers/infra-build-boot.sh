#!/bin/bash

cd /tmp

export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0
apt-get upgrade -y -qq -o Dpkg::Use-Pty=0

# bootloader
# mtools - efi iso boot

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 \
  grub-efi-amd64-bin grub-pc-bin grub2-common \
  syslinux-common \
  isolinux mtools dosfstools

# for grub root variable is set to memdisk initially
# grub_cmdpath is the location from which core.img was loaded as an absolute directory name

# grub efi binary
mkdir -p /efi/EFI/BOOT/

# use regexp to remove path part to determine the root
cat > /tmp/grub_efi.cfg << EOF
regexp --set base "(.*)/" \$cmdpath
regexp --set base "(.*)/" \$base
set root=\$base
configfile \$cmdpath/grub.cfg
EOF

cat > /tmp/grub_bios.cfg << EOF
prefix=
root=\$cmdpath
configfile \$cmdpath/EFI/BOOT/grub.cfg
EOF

LEGACYDIR="/efi/syslinux"
ISODIR="/efi/isolinux"
mkdir -p $LEGACYDIR
mkdir -p $ISODIR

# normal - loaded by default
# part_msdos part_gpt - mbr and gpt partition table support
# fat ext2 ntfs iso9660 hfsplus - search by fs labels and read files from fs
# linux - boot linux kernel
# linux16 - boot linux kernel 16 bit for netboot-xyz
# ntldr - boot windows
# loadenv - read andd write grub file used for boot once configuration
# test - conditionals in grub config file
# regexp - regexp, used to remove path part from a variable
# smbios - detect motherboard ID
# loopback - boot iso files
# chain - chain boot
# search - find partitions (by label or uuid, but no suport for part_label)

# configfile - is this really needed

# minicmd ls cat - interactive debug in grub shell

GRUB_MODULES="normal part_msdos part_gpt fat ext2 iso9660 ntfs hfsplus linux linux16 loadenv test regexp smbios loopback chain search configfile minicmd ls cat"

# for more control, consider just invoking grub-mkimage directly
# grub-mkstandalone just a wrapper on top of grub-mkimage

grub-mkstandalone --format=i386-pc --output="$LEGACYDIR/core.img" --install-modules="$GRUB_MODULES biosdisk ntldr" --modules="$GRUB_MODULES biosdisk" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_bios.cfg"
grub-mkstandalone --format=x86_64-efi --output="/efi/EFI/BOOT/BOOTX64.efi" --install-modules="$GRUB_MODULES linuxefi" --modules="$GRUB_MODULES linuxefi" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_efi.cfg"

cp /usr/lib/grub/i386-pc/boot_hybrid.img $ISODIR/

# bios boot for booting from a CD-ROM drive
cat /usr/lib/grub/i386-pc/cdboot.img $LEGACYDIR/core.img > $ISODIR/bios.img
rm -rf $LEGACYDIR/core.img

# EFI boot partition - FAT16 disk image
dd if=/dev/zero of=$ISODIR/efiboot.img bs=1M count=10 && \
mkfs.vfat $ISODIR/efiboot.img && \
LC_CTYPE=C mmd -i $ISODIR/efiboot.img EFI EFI/BOOT && \
LC_CTYPE=C mcopy -i $ISODIR/efiboot.img /efi/EFI/BOOT/BOOTX64.efi ::EFI/BOOT/
