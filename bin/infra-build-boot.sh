#!/bin/bash

# Requirements:
# - Does not need /home
# - Does not need /etc or /usr rw
# - Does not need to run as root or sudo
# - Does not use the network

# initramfs and most tools generating initramfs are designed to be host specific

# In general each kernel version will have to have its own initramfs
# but with a bit of work it is possible to make initramfs generic (not HW or host SW specific)

# https://fai-project.org/
# This is also way more powerful (systemd volatile)

# A read-only /etc is increasingly common on embedded devices.
# A rarely-changing /etc is also increasingly common on desktop and server installations, with files like /etc/mtab and /etc/resolv.conf located on another filesystem and symbolically linked in /etc (so that files in /etc need to be modified when installing software or when the computer's configuration changes, but not when mounting a USB drive or connecting in a laptop to a different network).
# The emerging standard is to have a tmpfs filesystem mounted on /run and symbolic links in /etc like

# Create a temporary file called rdexec and copy it into initramfs to be executed
# This solution only requires dropping one single hook file into initramfs
# This argument allows calling out to EFI parition from within initramfs to execute arbitrary code
# Future goal - instead of executing arbitrary code, try to just create additional files and drop them
# For user management switch to homectl and portable home directories

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

cd /tmp

. ./infra-env.sh

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

mkdir -p /efi /lib

# TODO - remove bash dependency

# TODO try to use libudev-compat vdevd instead of udev

if [[ "$ID" == alpine ]]; then
  # todo  - kernel modules and not loaded, also mouting /lib/modules does not work for some reason, config is not executed
  apk add squashfs-tools kmod udev coreutils unzip wget ca-certificates git build-base bash make pkgconfig kmod-dev fts-dev findmnt gcompat

  # make defautl shell bash for now
  rm -rf /bin/sh
  ln -sf /bin/bash /bin/sh
else
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y -qq -o Dpkg::Use-Pty=0
  apt-get upgrade -y -qq -o Dpkg::Use-Pty=0
  apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 squashfs-tools kmod udev coreutils unzip wget ca-certificates git
  apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 libkmod-dev pkg-config mount g++ make
fi

unsquashfs /efi/kernel/modules
mv squashfs-root /lib/modules

# dracut official release
#rm -rf 055.zip dracut-055
#wget --no-verbose --no-check-certificate https://github.com/dracutdevs/dracut/archive/refs/tags/055.zip
#unzip -q 055.zip
#cd dracut-055

git clone https://github.com/dracutdevs/dracut.git dracutdir

# swith to my branch for now
# git clone https://github.com/LaszloGombos/dracut.git dracutdir

# patch dracut
#cp -av dracut/* dracutdir

# build dracut from source
cd dracutdir
bash -c "./configure --disable-documentation"
make 2>/dev/null
make install
cd ..

mkdir -p /tmp/dracut
mkdir -p /efi/kernel

# fake to satisfy mandatory dependencies
mv /bin/tar /tmp/
mv /bin/gzip /tmp/

> /bin/tar
> /usr/sbin/dmsetup
> /bin/gzip

# Symlinks
rm -rf /usr/sbin/rmmod
> /usr/sbin/rmmod

# todo - mount the modules file earlier instead of duplicating them
# this probably need to be done on udev stage (pre-mount is too late)

# to debug, add the following dracut modules
# kernel-modules shutdown terminfo debug

# dracut-systemd adds about 4MB (compressed)

# bare minimium modules "base rootfs-block"

#--mount "/run/media/efi/kernel/modules /usr/lib/modules squashfs ro,noexec,nosuid,nodev" \

# filesystem kernel modules
# nls_XX - to mount vfat
# isofs - to find root within iso file
# autofs4 - systemd will try to load this (maybe because of fstab)

# storage kernel modules
# ahci - for SATA devices on modern AHCI controllers
# nvme - for NVME (M.2, PCI-E) devices
# xhci_pci, uas - usb
# sdhci_acpi, mmc_block - mmc

# sd_mod for all SCSI, SATA, and PATA (IDE) devices
# ehci_pci and usb_storage for USB storage devices
# virtio_blk and virtio_pci for QEMU/KVM VMs using VirtIO for storage
# ehci_pci - USB 2.0 storage devices

DEBUG='--debug --verbose'

dracut --nofscks --force --no-hostonly --no-early-microcode --no-compress --reproducible --tmpdir /tmp/dracut --keep \
  --add-drivers 'autofs4 squashfs overlay nls_iso8859_1 isofs ntfs ahci nvme xhci_pci uas sdhci_acpi mmc_block ata_piix ata_generic pata_acpi cdrom sr_mod virtio_scsi' \
  --modules 'dmsquash-live' \
  --include /tmp/infra-init.sh  /usr/lib/dracut/hooks/pre-pivot/00-init.sh \
  --aggresive-strip \
  initrd.img $KERNEL

rm initrd.img

cd /tmp/dracut/dracut.*/initramfs

# Clean some dracut info files
rm -rf usr/lib/dracut/build-parameter.txt
rm -rf usr/lib/dracut/dracut-*
rm -rf usr/lib/dracut/modules.txt

# when the initrd image contains the whole CD ISO - see https://github.com/livecd-tools/livecd-tools/blob/main/tools/livecd-iso-to-pxeboot.sh
rm -rf usr/lib/dracut/hooks/pre-udev/30-dmsquash-liveiso-genrules.sh

# todo - ideally dm dracut module is not included instead of this hack
rm -rf usr/lib/dracut/hooks/pre-udev/30-dm-pre-udev.sh
rm -rf usr/lib/dracut/hooks/shutdown/25-dm-shutdown.sh
rm -rf usr/sbin/dmsetup
rm -rf lib/modules/$KERNEL/kernel/drivers/md

# optimize - Remove empty (fake) binaries
find usr/bin usr/sbin -type f -empty -delete -print

ls -la bin
ls -la usr/sbin

# just symlinks in alpine
rm -rf  usr/sbin/chroot
rm -rf  bin/dmesg

rm -rf var/tmp
rm -rf root

rm -rf etc/fstab.empty
rm -rf etc/cmdline.d
rm -rf etc/ld.so.conf.d/libc.conf
rm -rf etc/ld.so.conf

# todo - chmod is used by my init script and will break boot
#rm -rf usr/bin/chmod

# kexec can only handle one initrd file
#find usr/lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/modules.img
#rm -rf usr/lib/modules

#mkdir updates
#cd updates

#mkdir -p usr/bin/
#mkdir -p etc/systemd/system/basic.target.wants/ usr/lib/systemd/system/

# alpine needs this hack
#cp /tmp/iso-scan.sh  sbin/iso-scan

#ln -sf /lib/systemd/system/boot.service etc/systemd/system/basic.target.wants/boot.service

mv /tmp/tar /bin/
mv /tmp/gzip /bin/

if [[ "$ID" == alpine ]]; then
  apk add cpio
else
  apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 cpio
fi

# Populate logs with the list of filenames
find .
ls -lRa .
find . -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd.img
ls -lha /efi/kernel/initrd.img

# Keep initramfs simple and do not require networking

# todo --debug --no-early-microcode --xz --keep --verbose --no-compress --no-kernel
# todo - interesting modules , usrmount, livenet, convertfs qemu qemu-net
# todo - use --no-kernel and mount modules early, write a module 00mountmodules or 01mountmodules

# include modules that might be reqired to find and mount modules file
# nls_iso8859_1 - mount vfat EFI partition if modules file is in EFI
# isofs - mount iso file if modules file is inside the iso
# ntfs - iso file itself might be stored on the ntfs filesystem
# ahci, uas (USB Attached SCSI), nvme - when booting on bare metal, to find the partition and filesystem

# todo - idea: break up initrd into 2 files - one with modules and one without modules, look into of the modules part can be conbined with the modules file
# find updates -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/updates.img

# shutdown - to help kexec
# terminfo - to debug

# todo - upstream - 00-btrfs.conf
# https://github.com/dracutdevs/dracut/commit/0402b3777b1c64bd716f588ff7457b905e98489d

rm -rf /tmp/initrd /tmp/cleanup /tmp/updates /tmp/dracut
