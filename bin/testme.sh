
export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 autoconf build-essential libssl-dev gawk openssl libssl-dev libelf-dev libudev-dev libpci-dev flex bison cpio zstd wget bc kmod

cd /tmp/

rm -rf linux-5.15.32*
wget --no-check-certificate https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.32.tar.xz
tar -xf linux-5.15.32.tar.xz

cd linux-5.15.32

cat > x86_64.miniconf << EOF
# make ARCH=x86 allnoconfig KCONFIG_ALLCONFIG=x86_64.miniconf
# make ARCH=x86 -j $(nproc)
# boot arch/x86/boot/bzImage


# CONFIG_EMBEDDED is not set
# architecture independent
CONFIG_BINFMT_ELF=y
CONFIG_BINFMT_SCRIPT=y
CONFIG_NO_HZ=y
CONFIG_HIGH_RES_TIMERS=y
CONFIG_BLK_DEV=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_BLK_DEV_LOOP=y
CONFIG_EXT4_FS=y
CONFIG_EXT4_USE_FOR_EXT2=y
CONFIG_VFAT_FS=y
CONFIG_FAT_DEFAULT_UTF8=y
CONFIG_MISC_FILESYSTEMS=y
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_XATTR=y
CONFIG_SQUASHFS_ZLIB=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_NET=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_INET=y
CONFIG_IPV6=y
CONFIG_NETDEVICES=y
CONFIG_NET_CORE=y
CONFIG_NETCONSOLE=y
CONFIG_ETHERNET=y
CONFIG_COMPAT_32BIT_TIME=y
CONFIG_EARLY_PRINTK=y
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y

# architecture specific
CONFIG_64BIT=y
CONFIG_UNWINDER_FRAME_POINTER=y
CONFIG_PCI=y
CONFIG_BLK_DEV_SD=y
CONFIG_ATA=y
CONFIG_ATA_SFF=y
CONFIG_ATA_BMDMA=y
CONFIG_ATA_PIIX=y
CONFIG_NET_VENDOR_INTEL=y
CONFIG_E1000=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_RTC_CLASS=y

EOF


make ARCH=x86 allnoconfig KCONFIG_ALLCONFIG=x86_64.miniconf

cat .config
make -j24 bzImage
ls -lha arch/x86/boot/bzImage
exit



make distclean
make olddefconfig

./scripts/config --set-val CONFIG_CDROM y

# fs/fat/fat.ko
./scripts/config --set-val CONFIG_FAT_FS y

# fs/squashfs/squashfs.ko
./scripts/config --set-val CONFIG_SQUASHFS y
./scripts/config --set-val CONFIG_SQUASHFS_ZSTD y

# fs/fat/vfat.ko
./scripts/config --set-val CONFIG_VFAT_FS y
./scripts/config --set-val CONFIG_FAT_DEFAULT_CODEPAGE 437
./scripts/config --set-val CONFIG_FAT_DEFAULT_IOCHARSET iso8859-1

# fs/exfat/exfat.ko
./scripts/config --set-val CONFIG_EXFAT_FS y
./scripts/config --set-val CONFIG_EXFAT_DEFAULT_IOCHARSET utf8

# fs/isofs/isofs.ko
./scripts/config --set-val CONFIG_ISO9660_FS y

# drivers/ata/ahci.ko
./scripts/config --set-val CONFIG_SATA_AHCI y

# fs/overlayfs/overlay.ko
./scripts/config --set-val CONFIG_OVERLAY_FS y

./scripts/config --set-val CONFIG_ASHMEM y
./scripts/config --set-val CONFIG_ANDROID y
./scripts/config --set-val CONFIG_ANDROID_BINDER_IPC y
./scripts/config --set-val CONFIG_ANDROID_BINDERFS y

./scripts/config --set-val CONFIG_VIRT_DRIVERS y

./scripts/config --set-val CONFIG_USB_PCI y

./scripts/config --set-val CONFIG_MODULE_COMPRESS_ZSTD y

./scripts/config --set-val CONFIG_LOCKD_V4 y
## storage

# drivers/nvme/host/nvme.ko
./scripts/config --set-val CONFIG_BLK_DEV_NVME m

# drivers/mmc/core/mmc_core.ko
./scripts/config --set-val CONFIG_MMC m

# drivers/mmc/core/mmc_block.ko
./scripts/config --set-val CONFIG_MMC_BLOCK m

# drivers/block/virtio_blk.ko
./scripts/config --set-val CONFIG_VIRTIO_BLK m

# drivers/usb/storage/uas.ko
./scripts/config --set-val CONFIG_USB_UAS m

# fs/fuse/fuse.ko
./scripts/config --set-val CONFIG_FUSE_FS m

# fs/autofs/autofs4.ko
./scripts/config --set-val CONFIG_AUTOFS4_FS m

# fs/btrfs/btrfs.ko
./scripts/config --set-val CONFIG_BTRFS_FS m

# fs/ntfs3/ntfs3.ko
./scripts/config --set-val CONFIG_NTFS3_FS m

# fs/nfsd/nfsd.ko
./scripts/config --set-val CONFIG_NFSD m

./scripts/config --set-val CONFIG_NFS_FS m
./scripts/config --set-val CONFIG_NFS_V2 n
./scripts/config --set-val CONFIG_NFS_V3 m
./scripts/config --set-val CONFIG_NFS_V3_ACL y
./scripts/config --set-val CONFIG_NFS_V4 m

# fs/fuse/virtiofs.ko
./scripts/config --set-val CONFIG_VIRTIO_FS m

# video

# drivers/gpu/drm/i915/i915.ko
./scripts/config --set-val CONFIG_DRM_I915 m

# drivers/gpu/drm/nouveau/nouveau.ko
./scripts/config --set-val CONFIG_DRM_NOUVEAU m

# networking

# drivers/net/ethernet/intel/e1000/e1000.ko
./scripts/config --set-val CONFIG_E1000 m

# drivers/net/ethernet/intel/e1000/e1000e.ko
./scripts/config --set-val CONFIG_E1000E m

# drivers/net/virtio_net.ko
./scripts/config --set-val CONFIG_VIRTIO_NET m

# input

# drivers/hid/hid.ko
./scripts/config --set-val CONFIG_HID m

# drivers/hid/hid-generic.ko
./scripts/config --set-val CONFIG_HID_GENERIC m

# drivers/hid/usbhid/usbhid.ko
./scripts/config --set-val CONFIG_USB_HID m

# drivers/input/mouse/psmouse.ko
./scripts/config --set-val CONFIG_MOUSE_PS2 m

# usb

# drivers/usb/host/ehci-pci.ko
./scripts/config --set-val CONFIG_USB_XHCI_PCI m

# drivers/usb/host/ehci-hcd.ko
./scripts/config --set-val CONFIG_USB_EHCI_HCD m

# virtualization

# arch/x86/kvm/kvm.ko
./scripts/config --set-val CONFIG_KVM m

# arch/x86/kvm/kvm-intel.ko
./scripts/config --set-val CONFIG_KVM_INTEL m

# drivers/virtio/virtio.ko
./scripts/config --set-val CONFIG_VIRTIO m

# drivers/virtio/virtio_pci.ko
./scripts/config --set-val CONFIG_VIRTIO_PCI m

# sound

# sound/soundcore.ko
./scripts/config --set-val CONFIG_SOUND m

# sound/snd.ko
./scripts/config --set-val CONFIG_SND m

# Disable features
./scripts/config --set-val CONFIG_FTRACE n
./scripts/config --set-val CONFIG_DEBUG_KERNEL n
./scripts/config --set-val CONFIG_PRINTK_TIME n
./scripts/config --set-val CONFIG_DEBUG_FS n
./scripts/config --set-val CONFIG_STACK_VALIDATION n
./scripts/config --set-val CONFIG_DRM_LEGACY n
./scripts/config --set-val CONFIG_QUOTA n

#./scripts/config --set-val CONFIG_LOCKD m
#./scripts/config --set-val CONFIG_EXPORTFS m

cat .config

# Fix dependencies (flip some m to y)
make oldconfig

cat .config

make -j24 bzImage
make -j24 modules
make modules_install

du -h /lib/modules/5.15.32/
ls -lha arch/x86/boot/bzImage