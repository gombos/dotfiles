if ! [ -z "$REPO" ]; then
  cp $REPO/bin/* /tmp/
  cp $REPO/packages/* /tmp/
  cd /tmp
fi

mkdir /tmp/dracut

apk upgrade
apk update

apk add dracut-modules squashfs-tools wget tar

KVERSION=$(cd /lib/modules; ls -1 | tail -1)

find /usr/lib | grep .ko

dracut --no-hostonly --kernel-only --no-compress --keep --tmpdir /tmp/dracut \
  --add-drivers 'ntfs3 xhci_pci uas sdhci_acpi mmc_block pata_acpi virtio_scsi usbhid hid_generic hid' \
  --modules 'rootfs-block' \
  initrd.img $KVERSION

cd  /tmp/dracut/dracut.*/initramfs/

find lib/modules/ -name "*.ko"

mkdir -p /efi/kernel

find lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd_modules.img

cd /tmp

ls -lha /efi/kernel/initrd_modules.img

mksquashfs /lib/modules /efi/kernel/modules

# FIRMWARE

mv /lib/firmware /tmp/
mkdir -p /lib/firmware
cp -a /tmp/firmware/iwlwifi-*-72.ucode /lib/firmware/
cp -a /tmp/firmware/i915 /lib/firmware/
find /lib/firmware/

mksquashfs /lib/firmware /efi/kernel/firmware
rm -rf /tmp/initrd

# this is a large file.. 0.5G
wget --quiet -O - https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/snapshot/linux-firmware-20230919.tar.gz > /tmp/firmware.tar.gz
rm -rf /tmp/linux-firmware-*
cd /tmp
tar -xf firmware.tar.gz
cd /tmp/linux-firmware-*

rm -rf /lib/firmware
mkdir -p /lib/firmware
cp -a iwlwifi-*-72.ucode /lib/firmware/
cp -a i915 /lib/firmware/
find /lib/firmware/
