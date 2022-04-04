
export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 autoconf build-essential libssl-dev gawk openssl libssl-dev libelf-dev libudev-dev libpci-dev flex bison cpio zstd wget bc kmod

cd /tmp/

rm -rf linux-5.15.32*
wget --no-check-certificate https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.32.tar.xz
tar -xf linux-5.15.32.tar.xz

cd linux-5.15.32

make distclean
make olddefconfig

# builtin
./scripts/config --set-val CONFIG_ANDROID y
./scripts/config --set-val CONFIG_ANDROID_BINDER_IPC y
./scripts/config --set-val CONFIG_ANDROID_BINDERFS y

# fs/autofs/autofs4.ko
./scripts/config --set-val CONFIG_AUTOFS4_FS m
./scripts/config --set-val CONFIG_BLK_DEV_NVME m

# fs/btrfs/btrfs.ko
./scripts/config --set-val CONFIG_BTRFS_FS m

# drivers/gpu/drm/i915/i915.ko
./scripts/config --set-val CONFIG_DRM_I915 m

# drivers/gpu/drm/nouveau/nouveau.ko
./scripts/config --set-val CONFIG_DRM_NOUVEAU m

# drivers/net/ethernet/intel/e1000/e1000.ko
./scripts/config --set-val CONFIG_E1000 m

# drivers/net/ethernet/intel/e1000/e1000e.ko
./scripts/config --set-val CONFIG_E1000E m

./scripts/config --set-val CONFIG_HID m
./scripts/config --set-val CONFIG_ISO9660_FS m

# kernel/arch/x86/kvm/kvm.ko
./scripts/config --set-val CONFIG_KVM m

# kernel/arch/x86/kvm/kvm-intel.ko
./scripts/config --set-val CONFIG_KVM_INTEL m

./scripts/config --set-val CONFIG_MMC m
./scripts/config --set-val CONFIG_MMC_BLOCK m

# kernel/sound/soundcore.ko
./scripts/config --set-val CONFIG_SOUND m

# kernel/sound/snd.ko
./scripts/config --set-val CONFIG_SND m

./scripts/config --set-val CONFIG_MODULE_COMPRESS_ZSTD y
./scripts/config --set-val CONFIG_MODULE_COMPRESS_ZSTD_LEVEL 19

# drivers/input/mouse/psmouse.ko
./scripts/config --set-val CONFIG_MOUSE_PS2 m

# fs/ntfs3/ntfs3.ko
./scripts/config --set-val CONFIG_NFSD m

# fs/ntfs3/ntfs3.ko
./scripts/config --set-val CONFIG_NTFS3_FS m

# fs/overlayfs/overlay.ko
./scripts/config --set-val CONFIG_OVERLAY_FS m

# ahci
./scripts/config --set-val CONFIG_SATA_AHCI m

# xhci-pci
./scripts/config --set-val CONFIG_USB_XHCI_PCI m

# Disable kernel debug
./scripts/config --set-val CONFIG_FTRACE n
./scripts/config --set-val CONFIG_DEBUG_KERNEL n
./scripts/config --set-val CONFIG_PRINTK_TIME n
./scripts/config --set-val CONFIG_DEBUG_FS n
./scripts/config --set-val CONFIG_STACK_VALIDATION n

make oldconfig

cat .config

make -j24 bzImage
make -j24 modules
make modules_install

du -h /lib/modules/5.15.32/
ls -lha arch/x86/boot/bzImage