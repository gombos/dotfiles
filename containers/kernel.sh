# builds for abpout 2:30 hours on GA

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
./scripts/config --enable CONFIG_AUTOFS4_FS
./scripts/config --enable CONFIG_NLS_ISO8859_1
./scripts/config --enable CONFIG_IKCONFIG
./scripts/config --enable CONFIG_IKCONFIG_PROC
./scripts/config --enable CONFIG_ISO9660_FS
./scripts/config --enable CONFIG_SATA_AHCI
./scripts/config --enable CONFIG_OVERLAY_FS
./scripts/config --enable CONFIG_SCSI_VIRTIO

./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --disable CONFIG_DEBUG_INFO_BTF
./scripts/config --disable CONFIG_X86_X32
./scripts/config --disable CONFIG_FTRACE
./scripts/config --disable CONFIG_PRINTK_TIME

./scripts/config --enable  CONFIG_ANDROID
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

#make headers_install

#apt-get purge -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 autoconf build-essential libssl-dev gawk openssl libssl-dev libelf-dev libudev-dev libpci-dev flex bison cpio zstd wget bc kmod git squashfs-tools cpio dracut-core ca-certificates apt-utils ca-certificates git fakeroot gzip dracut-core wget linux-base sudo libelf1 python3 dkms build-essential rsync

find /boot/ /lib/modules/

#/usr/include/

exit

mkdir -p /efi/kernel
cp -r arch/x86/boot/bzImage /efi/kernel/vmlinuz

file /efi/kernel/vmlinuz

make -j16 modules
make INSTALL_MOD_STRIP=1 modules_install
make headers_install

make clean

mkdir /tmp/dracut

KVERSION=$(cd /lib/modules; ls -1 | tail -1)

find /usr/lib | grep .ko

dracut --no-hostonly --kernel-only --no-compress --keep --tmpdir /tmp/dracut \
  --add-drivers 'ntfs3 xhci_pci uas sdhci_acpi mmc_block pata_acpi virtio_scsi usbhid hid_generic hid' \
  --modules 'rootfs-block' \
  initrd.img $KVERSION

cd  /tmp/dracut/dracut.*/initramfs/

find lib/modules/ -name "*.ko"

find lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd_modules.img

# Make sure we have all the required modules built
$SCRIPTS/infra-install-vmware-workstation-modules.sh

cd /tmp

ls -lha /efi/kernel/initrd_modules.img

mksquashfs /usr/lib/modules /efi/kernel/modules
rm -rf /tmp/initrd

find /efi/kernel
ls -lRa /efi/kernel


