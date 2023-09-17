# builds for about 2:30 hours on GA

. $REPO/bin/infra-env.sh

cd /tmp

set -x

export DEBIAN_FRONTEND=noninteractive

rm -rf /etc/apt/sources.list.d/debian.sources
echo "deb https://deb.debian.org/debian ${RELEASE} main non-free-firmware" >> /etc/apt/sources.list
apt-get update -y -qq -o Dpkg::Use-Pty=0

#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 autoconf build-essential libssl-dev gawk openssl libssl-dev libelf-dev libudev-dev libpci-dev flex bison cpio zstd wget bc kmod git squashfs-tools cpio dracut-core ca-certificates apt-utils ca-certificates git fakeroot gzip dracut-core wget linux-base sudo libelf1 python3 dkms build-essential rsync linux-headers-generic

# device firmware - i916 and nvidea, Intel Wireless cards
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 firmware-linux-free firmware-misc-nonfree firmware-iwlwifi

find /lib/firmware

exit

rm -rf linux-*
rm -rf /boot/* /lib/modules/*

wget -q --no-check-certificate https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL.tar.xz
tar -xf linux-$KERNEL.tar.xz
rm -rf linux-$KERNEL.tar.xz
rm -rf /var/lib/apt /var/cache

cd linux-$KERNEL

cp /efi/kernel/initrd.img /tmp/initramfs.cpio.gz

ls -la /tmp/initramfs.cpio.gz

cp $REPO/containers/kernelconfig .config

cp .config oldconfig

#cat .config
./scripts/config --set-val CONFIG_BINFMT_ELF y
./scripts/config --set-val CONFIG_BINFMT_SCRIPT y
./scripts/config --set-val CONFIG_NO_HZ y
./scripts/config --set-val CONFIG_HIGH_RES_TIMERS y
./scripts/config --set-val CONFIG_BLK_DEV y
./scripts/config --set-val CONFIG_BLK_DEV_INITRD y
./scripts/config --set-val CONFIG_RD_GZIP y
./scripts/config --set-val CONFIG_MISC_FILESYSTEMS y
./scripts/config --set-val CONFIG_TMPFS y
./scripts/config --set-val CONFIG_COMPAT_32BIT_TIME y
./scripts/config --set-val CONFIG_PCI y
./scripts/config --set-val CONFIG_RTC_CLASS y

# x86_64 bit
./scripts/config --set-val CONFIG_64BIT y

# udev
./scripts/config --set-val CONFIG_SIGNALFD y
./scripts/config --set-val CONFIG_BLK_DEV_BSG y
./scripts/config --set-val CONFIG_NET y
./scripts/config --set-val CONFIG_DEVTMPFS y
./scripts/config --set-val CONFIG_DEVTMPFS_MOUNT y
./scripts/config --set-val CONFIG_INOTIFY_USER y
./scripts/config --set-val CONFIG_PROC_FS y
./scripts/config --set-val CONFIG_SYSFS y

# reboot
./scripts/config --set-val CONFIG_ACPI y

# CPU microcode
./scripts/config --set-val CONFIG_MICROCODE y
./scripts/config --set-val CONFIG_MICROCODE_AMD y
./scripts/config --set-val CONFIG_MICROCODE_INTEL y

# EFI
 ./scripts/config --set-val CONFIG_EFI y
 ./scripts/config --set-val CONFIG_EFI_STUB y
 ./scripts/config --set-val CONFIG_EFI_HANDOVER_PROTOCOL y

# modules
./scripts/config --set-val CONFIG_MODULES y

# unix - for udev
./scripts/config --set-val CONFIG_UNIX y

# Allows to boot with noinitrd in qemu
# ahci, libahci
./scripts/config --set-val CONFIG_SATA_AHCI y

# Allows to boot with noinitrd in qemu
# libata
./scripts/config --set-val CONFIG_ATA y
./scripts/config --set-val CONFIG_ATA_SFF y

# Allows to boot with noinitrd in qemu
# scsi_mod
./scripts/config --set-val CONFIG_SCSI y

# Allows to boot with noinitrd in qemu
# sd_mod
./scripts/config --set-val CONFIG_BLK_DEV_SD y

# loop
./scripts/config --set-val CONFIG_BLK_DEV_LOOP y

# squashfs
./scripts/config --set-val CONFIG_SQUASHFS y
./scripts/config --set-val CONFIG_SQUASHFS_ZLIB y

# overlay
./scripts/config --set-val CONFIG_OVERLAY_FS y

# Allows to boot with noinitrd in qemu
# ext4
./scripts/config --set-val CONFIG_EXT4_FS y
./scripts/config --set-val CONFIG_EXT4_USE_FOR_EXT2 y

# 8250
./scripts/config --set-val CONFIG_SERIAL_8250 y
./scripts/config --set-val CONFIG_SERIAL_8250_CONSOLE y

# nls_cp437
./scripts/config --set-val CONFIG_NLS_CODEPAGE_437 y

# nls_iso8859-1
./scripts/config --set-val CONFIG_NLS_ISO8859_1 y

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

# virtio - linode
./scripts/config --set-val CONFIG_VIRTIO y

# virtio_pci - linode
./scripts/config --set-val CONFIG_VIRTIO_PCI y

# virtio_scsi - linode
./scripts/config --set-val CONFIG_SCSI_VIRTIO y

# virtio_net - linode
./scripts/config --set-val CONFIG_VIRTIO_NET y

# virtiofs - linode
./scripts/config --set-val CONFIG_VIRTIO_FS y

# from https://docs.getutm.app/guest-support/linux/#drivers
./scripts/config --set-val CONFIG_VIRTIO y

./scripts/config --set-val CONFIG_VIRTIO_RING y

./scripts/config --set-val CONFIG_VIRTIO_PCI y

./scripts/config --set-val CONFIG_VIRTIO_BALLOON y

# for storage devices
./scripts/config --set-val CONFIG_VIRTIO_BLK y

# for console devices
./scripts/config --set-val CONFIG_VIRTIO_CONSOLE y

# for networking
./scripts/config --set-val CONFIG_VIRTIO_NET y

# for graphical output
./scripts/config --set-val CONFIG_DRM_VIRTIO_GPU y

# for VirtFS directory sharing
./scripts/config --set-val CONFIG_NET_9P y
./scripts/config --set-val CONFIG_NET_9P_VIRTIO y
./scripts/config --set-val CONFIG_9P_FS y
./scripts/config --set-val CONFIG_9P_FS_POSIX_ACL y

# for VirtioFS directory sharing
./scripts/config --set-val CONFIG_VIRTIO_FS y

# Disable features
./scripts/config --set-val CONFIG_FTRACE n
./scripts/config --set-val CONFIG_DEBUG_KERNEL n
./scripts/config --set-val CONFIG_PRINTK_TIME n
./scripts/config --set-val CONFIG_DEBUG_FS n
./scripts/config --set-val CONFIG_STACK_VALIDATION n
./scripts/config --set-val CONFIG_DRM_LEGACY n
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

# proxmox

#  28 -m INTEL_MEI_WDT \
#  29 -d CONFIG_SND_PCM_OSS \
#  30 -e CONFIG_TRANSPARENT_HUGEPAGE_MADVISE \
#  31 -d CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS \
#  32 -m CONFIG_CEPH_FS \
#  33 -m CONFIG_BLK_DEV_NBD \
#  34 -m CONFIG_BLK_DEV_RBD \
#  35 -m CONFIG_BLK_DEV_UBLK \
#  36 -d CONFIG_SND_PCSP \
#  37 -m CONFIG_BCACHE \
#  38 -m CONFIG_JFS_FS \
#  39 -m CONFIG_HFS_FS \
#  40 -m CONFIG_HFSPLUS_FS \
#  41 -e CIFS_SMB_DIRECT \
#  42 -e CONFIG_SQUASHFS_DECOMP_MULTI_PERCPU \
#  43 -e CONFIG_BRIDGE \
#  44 -e CONFIG_BRIDGE_NETFILTER \
#  45 -e CONFIG_BLK_DEV_SD \
#  46 -e CONFIG_BLK_DEV_SR \
#  47 -e CONFIG_BLK_DEV_DM \
#  48 -m CONFIG_BLK_DEV_NVME \
#  49 -e CONFIG_NLS_ISO8859_1 \
#  50 -d CONFIG_INPUT_EVBUG \
#  51 -d CONFIG_CPU_FREQ_DEFAULT_GOV_ONDEMAND \
#  52 -d CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL \
#  53 -e CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE \
#  54 -e CONFIG_SYSFB_SIMPLEFB \
#  55 -e CONFIG_DRM_SIMPLEDRM \
#  56 -d CONFIG_MODULE_SIG \
#  57 -d CONFIG_MEMCG_DISABLED \
#  58 -e CONFIG_MEMCG_SWAP_ENABLED \
#  59 -e CONFIG_HYPERV \
#  60 -m CONFIG_VFIO_IOMMU_TYPE1 \
#  61 -m CONFIG_VFIO_VIRQFD \
#  62 -m CONFIG_VFIO \
#  63 -m CONFIG_VFIO_PCI \
#  64 -m CONFIG_USB_XHCI_HCD \
#  65 -m CONFIG_USB_XHCI_PCI \
#  66 -m CONFIG_USB_EHCI_HCD \
#  67 -m CONFIG_USB_EHCI_PCI \
#  68 -m CONFIG_USB_EHCI_HCD_PLATFORM \
#  69 -m CONFIG_USB_OHCI_HCD \
#  70 -m CONFIG_USB_OHCI_HCD_PCI \
#  71 -m CONFIG_USB_OHCI_HCD_PLATFORM \
#  72 -d CONFIG_USB_OHCI_HCD_SSB \
#  73 -m CONFIG_USB_UHCI_HCD \
#  74 -d CONFIG_USB_SL811_HCD_ISO \
#  75 -e CONFIG_MEMCG_KMEM \
#  76 -d CONFIG_DEFAULT_CFQ \
#  77 -e CONFIG_DEFAULT_DEADLINE \
#  78 -e CONFIG_MODVERSIONS \
#  79 -e CONFIG_ZSTD_COMPRESS \
#  80 -d CONFIG_DEFAULT_SECURITY_DAC \
#  81 -e CONFIG_DEFAULT_SECURITY_APPARMOR \
#  82 --set-str CONFIG_DEFAULT_SECURITY apparmor \
#  83 -e CONFIG_MODULE_ALLOW_BTF_MISMATCH \
#  84 -d CONFIG_UNWINDER_ORC \
#  85 -d CONFIG_UNWINDER_GUESS \
#  86 -e CONFIG_UNWINDER_FRAME_POINTER \
#  87 --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""\
#  88 --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""\
#  89 -d CONFIG_SECURITY_LOCKDOWN_LSM \
#  90 -d CONFIG_SECURITY_LOCKDOWN_LSM_EARLY \
#  91 --set-str CONFIG_LSM yama,integrity,apparmor \
#  92 -e CONFIG_PAGE_TABLE_ISOLATION

make oldconfig
#cat .config

diff .config oldconfig

make -j$(nproc) bzImage 2>&1 > /dev/null
make -j$(nproc) modules 2>&1 > /dev/null

make install
make INSTALL_MOD_STRIP=1 modules_install 2>&1 > /dev/null

# Make sure we have all the required modules built
$REPO/bin/infra-install-vmware-workstation-modules.sh

#make headers_install

#find /boot/ /lib/modules/

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

df -h
