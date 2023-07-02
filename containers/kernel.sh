# builds for about 2:30 hours on GA

. $REPO/bin/infra-env.sh

cd /tmp

set -x

export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 autoconf build-essential libssl-dev gawk openssl libssl-dev libelf-dev libudev-dev libpci-dev flex bison cpio zstd wget bc kmod git squashfs-tools cpio dracut-core ca-certificates apt-utils ca-certificates git fakeroot gzip dracut-core wget linux-base sudo libelf1 python3 dkms build-essential rsync linux-headers-generic

rm -rf linux-*
rm -rf /boot/* /lib/modules/*

wget --no-check-certificate https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL.tar.xz
tar -xf linux-$KERNEL.tar.xz

cd linux-$KERNEL

cp /efi/kernel/initrd.img /tmp/initramfs.cpio.gz

ls -la /tmp/initramfs.cpio.gz

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

# x86_64 bit
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

# CPU microcode
./scripts/config --enable CONFIG_MICROCODE
./scripts/config --enable CONFIG_MICROCODE_AMD
./scripts/config --enable CONFIG_MICROCODE_INTEL

# EFI
 ./scripts/config --enable CONFIG_EFI
 ./scripts/config --enable CONFIG_EFI_STUB
 ./scripts/config --enable CONFIG_EFI_HANDOVER_PROTOCOL

# modules
./scripts/config --enable CONFIG_MODULES

# unix - for udev
./scripts/config --enable CONFIG_UNIX

# Allows to boot with noinitrd in qemu
# ahci, libahci
./scripts/config --enable CONFIG_SATA_AHCI

# Allows to boot with noinitrd in qemu
# libata
./scripts/config --enable CONFIG_ATA
./scripts/config --enable CONFIG_ATA_SFF

# Allows to boot with noinitrd in qemu
# scsi_mod
./scripts/config --enable CONFIG_SCSI

# Allows to boot with noinitrd in qemu
# sd_mod
./scripts/config --enable CONFIG_BLK_DEV_SD

# loop
./scripts/config --enable CONFIG_BLK_DEV_LOOP

# squashfs
./scripts/config --enable CONFIG_SQUASHFS
./scripts/config --enable CONFIG_SQUASHFS_ZLIB

# overlay
./scripts/config --enable CONFIG_OVERLAY_FS

# Allows to boot with noinitrd in qemu
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
./scripts/config --enable CONFIG_VFAT_FS

# cdrom
./scripts/config --enable CONFIG_BLK_DEV_SR

# autofs4
./scripts/config --enable CONFIG_AUTOFS4_FS

# isofs
./scripts/config --enable CONFIG_ISO9660_FS

# modules

# ntfs3
./scripts/config --module CONFIG_NTFS3_FS

# exfat
./scripts/config --module CONFIG_EXFAT_FS
./scripts/config --set-str CONFIG_EXFAT_DEFAULT_IOCHARSET "iso8859-1"

# mmc_core
./scripts/config --set-val CONFIG_MMC m

# mmc_block
./scripts/config --set-val CONFIG_MMC_BLOCK m

# uas
./scripts/config --set-val CONFIG_USB_UAS m

# fuse
./scripts/config --set-val CONFIG_FUSE_FS m

# btrfs
./scripts/config --set-val CONFIG_BTRFS_FS m

# device mapper
./scripts/config --set-val CONFIG_BLK_DEV_DM m

# msdos
./scripts/config --set-val CONFIG_MSDOS_FS m

./scripts/config --enable CONFIG_IKCONFIG
./scripts/config --enable CONFIG_IKCONFIG_PROC

./scripts/config --set-val CONFIG_ANDROID_BINDER_IPC y
./scripts/config --set-val CONFIG_ANDROID_BINDERFS y
./scripts/config --set-str CONFIG_ANDROID_BINDER_DEVICES "binder,hwbinder,vndbinder"

# nvme_core
./scripts/config --enable  CONFIG_NVME_CORE

# nvme
./scripts/config --enable  CONFIG_BLK_DEV_NVME

./scripts/config --set-str CONFIG_INITRAMFS_SOURCE "/tmp/initramfs.cpio.gz"

# virtualization

# kvm
./scripts/config --set-val CONFIG_KVM m

# kvm-intel
./scripts/config --set-val CONFIG_KVM_INTEL m

# virtio
./scripts/config --set-val CONFIG_VIRTIO m

# virtio_pci
./scripts/config --set-val CONFIG_VIRTIO_PCI m

# virtio_scsi
./scripts/config --set-val CONFIG_SCSI_VIRTIO m

# virtio_net
./scripts/config --set-val CONFIG_VIRTIO_NET m

# virtiofs
./scripts/config --set-val CONFIG_VIRTIO_FS m

# Disable features
./scripts/config --set-val CONFIG_FTRACE n
./scripts/config --set-val CONFIG_DEBUG_KERNEL n
./scripts/config --set-val CONFIG_PRINTK_TIME n
./scripts/config --set-val CONFIG_DEBUG_FS n
./scripts/config --set-val CONFIG_STACK_VALIDATION n
./scripts/config --set-val CONFIG_DRM_LEGACY n
./scripts/config --set-val CONFIG_QUOTA n
./scripts/config --set-val CONFIG_ACPI_DEBUGGER n
./scripts/config --set-val CONFIG_BT_DEBUGFS n
./scripts/config --set-val CONFIG_NFC n
./scripts/config --set-val CONFIG_L2TP_DEBUGFS n
./scripts/config --set-val CONFIG_NTFS_FS n
./scripts/config --set-val CONFIG_REISERFS_FS n
./scripts/config --set-val CONFIG_JFS_FS n
./scripts/config --set-val CONFIG_CAN n
./scripts/config --set-val CONFIG_INPUT_EVBUG n
./scripts/config --set-val CONFIG_INPUT_JOYSTICK n
./scripts/config --set-val SYSTEM_TRUSTED_KEYS n
./scripts/config --set-val SYSTEM_REVOCATION_KEYS n
./scripts/config --set-val CONFIG_DEBUG_INFO_BTF n
./scripts/config --set-val CONFIG_X86_X32 n
./scripts/config --set-val CONFIG_FTRACE n

make oldconfig
cat .config

diff .config oldconfig

make -j$(nproc) bzImage
make -j$(nproc) modules

make install
make INSTALL_MOD_STRIP=1 modules_install

# Make sure we have all the required modules built
$REPO/bin/infra-install-vmware-workstation-modules.sh

#make headers_install

find /boot/ /lib/modules/

#/usr/include/
#make headers_install
#make clean


# todo - add a stp to generate unified kernel
#echo "Signing unified kernel"

#objcopy \
#    --add-section .osrel=/usr/lib/os-release --change-section-vma .osrel=0x20000 \
#    --add-section .cmdline=cmdline --change-section-vma .cmdline=0x30000 \
#    --add-section .linux=/boot/vmlinuz --change-section-vma .linux=0x2000000 \
#    --add-section .initrd=/boot/initrd.img --change-section-vma .initrd=0x3000000 \
#    /usr/lib/systemd/boot/efi/linuxx64.efi.stub \
#    vmlinuz.unsigned.efi
# see https://github.com/pop-os/core/blob/master/res/image.sh
