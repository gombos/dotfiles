# builds for about 2:30 hours on GA

. $REPO/bin/infra-env.sh

cd /tmp

set -x

export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 autoconf build-essential libssl-dev gawk openssl libssl-dev libelf-dev libudev-dev libpci-dev flex bison cpio zstd wget bc kmod git squashfs-tools cpio dracut-core ca-certificates apt-utils ca-certificates git fakeroot gzip dracut-core wget linux-base sudo libelf1 python3 dkms build-essential rsync linux-headers-generic

rm -rf linux-*
wget --no-check-certificate https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL.tar.xz
tar -xf linux-$KERNEL.tar.xz

cd linux-$KERNEL

cp /efi/kernel/initrd.img /tmp/initramfs.cpio.gz

ls -la /tmp/initramfs.cpio.gz
file /tmp/initramfs.cpio.gz

cp $REPO/containers/kernelconfig .config

cp .config oldconfig

cat .config
./scripts/config --enable CONFIG_BINFMT_ELF
./scripts/config --enable CONFIG_BINFMT_SCRIPT
./scripts/config --enable CONFIG_NO_HZ
./scripts/config --enable CONFIG_HIGH_RES_TIMERS
./scripts/config --enable CONFIG_BLK_DEV
./scripts/config --enable CONFIG_BLK_DEV_INITRD
./scripts/config --enable CONFIG_RD_GZIP
./scripts/config --enable CONFIG_MISC_FILESYSTEMS
./scripts/config --enable CONFIG_TMPFS
./scripts/config --enable CONFIG_COMPAT_32BIT_TIME
./scripts/config --enable CONFIG_PCI
./scripts/config --enable CONFIG_RTC_CLASS

# x86 specific
./scripts/config --enable CONFIG_64BIT

# udev
./scripts/config --enable CONFIG_SIGNALFD
./scripts/config --enable CONFIG_BLK_DEV_BSG
./scripts/config --enable CONFIG_NET
./scripts/config --enable CONFIG_DEVTMPFS
./scripts/config --enable CONFIG_DEVTMPFS_MOUNT
./scripts/config --enable CONFIG_INOTIFY_USER
./scripts/config --enable CONFIG_PROC_FS
./scripts/config --enable CONFIG_SYSFS

# reboot
./scripts/config --enable CONFIG_ACPI

# microcode
./scripts/config --enable CONFIG_MICROCODE
./scripts/config --enable CONFIG_MICROCODE_AMD
./scripts/config --enable CONFIG_MICROCODE_INTEL

# EFI
 ./scripts/config --enable CONFIG_EFI
 ./scripts/config --enable CONFIG_EFI_STUB

# module
./scripts/config --enable CONFIG_MODULES

# staring here are optionals (can be modules)

# unix - for udev
./scripts/config --enable CONFIG_UNIX

# ahci, libahci
./scripts/config --enable CONFIG_SATA_AHCI

# libata
./scripts/config --enable CONFIG_ATA
./scripts/config --enable CONFIG_ATA_SFF

# scsi_mod
./scripts/config --enable CONFIG_SCSI

# sd_mod
./scripts/config --enable CONFIG_BLK_DEV_SD

# loop
./scripts/config --enable CONFIG_BLK_DEV_LOOP

# squashfs
./scripts/config --enable CONFIG_SQUASHFS
./scripts/config --enable CONFIG_SQUASHFS_ZLIB

# overlay
./scripts/config --enable CONFIG_OVERLAY_FS

# ext4
./scripts/config --enable CONFIG_EXT4_FS
./scripts/config --enable CONFIG_EXT4_USE_FOR_EXT2

# 8250
./scripts/config --enable CONFIG_SERIAL_8250
./scripts/config --enable CONFIG_SERIAL_8250_CONSOLE

# nls_cp437
./scripts/config --enable CONFIG_NLS_CODEPAGE_437

# nls_iso8859-1
./scripts/config --enable CONFIG_NLS_ISO8859_1

# fat
./scripts/config --enable CONFIG_FAT_FS
./scripts/config --enable CONFIG_MSDOS_PARTITION
./scripts/config --set-str CONFIG_FAT_DEFAULT_CODEPAGE 437
./scripts/config --set-str CONFIG_FAT_DEFAULT_IOCHARSET "iso8859-1"
./scripts/config --enable CONFIG_NCPFS_SMALLDOS

# vfat
./scripts/config --enableCONFIG_VFAT_FS

# cdrom
./scripts/config --enable CONFIG_BLK_DEV_SR

# autofs4
./scripts/config --enable CONFIG_AUTOFS4_FS

# isofs
./scripts/config --enable CONFIG_ISO9660_FS

# modules

# ntfs3
#CONFIG_NTFS3_FS=m

# exfat
#CONFIG_EXFAT_FS=m
#CONFIG_EXFAT_DEFAULT_IOCHARSET="iso8859-1"

# nvme_core
#CONFIG_NVME_CORE=m

# nvme
#CONFIG_BLK_DEV_NVME=m

# mmc_core
#CONFIG_MMC=m

# mmc_block
#CONFIG_MMC_BLOCK=m

# uas
#CONFIG_USB_UAS=m

# fuse
#CONFIG_FUSE_FS=m

# btrfs
#CONFIG_BTRFS_FS=m

# device mapper
#CONFIG_BLK_DEV_DM=m

# CONFIG_INITRAMFS_SOURCE="/tmp/initramfs.cpio.gz"

# msdos
#CONFIG_MSDOS_FS=m

./scripts/config --enable CONFIG_IKCONFIG
./scripts/config --enable CONFIG_IKCONFIG_PROC
./scripts/config --enable CONFIG_SCSI_VIRTIO

./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --disable CONFIG_DEBUG_INFO_BTF
./scripts/config --disable CONFIG_X86_X32
./scripts/config --disable CONFIG_FTRACE
./scripts/config --disable CONFIG_PRINTK_TIME

./scripts/config --enable  CONFIG_ANDROID_BINDER_IPC
./scripts/config --enable  CONFIG_ANDROID_BINDERFS
./scripts/config --set-str CONFIG_ANDROID_BINDER_DEVICES ""

./scripts/config --disable CONFIG_INPUT_JOYSTICK
./scripts/config --enable  CONFIG_NVME_CORE
./scripts/config --enable  CONFIG_BLK_DEV_NVME

./scripts/config --set-str CONFIG_INITRAMFS_SOURCE "/tmp/initramfs.cpio.gz"

./scripts/config --disable CONFIG_ACPI_DEBUGGER
./scripts/config --disable CONFIG_BT_DEBUGFS
./scripts/config --disable CONFIG_NFC
./scripts/config --disable CONFIG_L2TP_DEBUGFS

./scripts/config --disable CONFIG_NTFS_FS
./scripts/config --disable CONFIG_REISERFS_FS
./scripts/config --disable CONFIG_JFS_FS
./scripts/config --disable CONFIG_CAN

make oldconfig
cat .config

diff .config oldconfig

make -j$(nproc) bzImage
make -j$(nproc) modules

rm -rf /boot/* /lib/modules/*

make install
make INSTALL_MOD_STRIP=1 modules_install

# Make sure we have all the required modules built
$REPO/bin/infra-install-vmware-workstation-modules.sh

#make headers_install

find /boot/ /lib/modules/

#/usr/include/
#make headers_install
#make clean
