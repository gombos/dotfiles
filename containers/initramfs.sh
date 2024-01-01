if ! [ -z "$REPO" ]; then
  cp $REPO/bin/* /tmp/
  cp $REPO/packages/* /tmp/
  cd /tmp
fi

mkdir /tmp/dracut

apk upgrade
apk update

apk add dracut-modules squashfs-tools wget tar rsync intel-ucode

KVERSION=$(cd /lib/modules; ls -1 | tail -1)

find /usr/lib | grep .ko

dracut --no-hostonly --kernel-only --no-compress --keep --tmpdir /tmp/dracut \
  --add-drivers 'exfat ntfs3 xhci_pci uas sdhci_acpi mmc_block pata_acpi virtio_scsi usbhid hid_generic hid' \
  --modules 'rootfs-block' \
  initrd.img $KVERSION

cd  /tmp/dracut/dracut.*/initramfs/

find lib/modules/ -name "*.ko"

mkdir -p /efi/kernel

find lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd_modules.img
cat /boot/intel-ucode.img | gzip --best > /efi/kernel/initrd_intel.img

cd /tmp

ls -lha /efi/kernel/initrd_modules.img /efi/kernel/initrd_intel.img

mksquashfs /lib/modules /efi/kernel/modules

# FIRMWARE

# this is a large file.. 0.5G
wget --quiet -O - https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/snapshot/linux-firmware-20231211.tar.gz > /tmp/firmware.tar.gz
rm -rf /tmp/linux-firmware-*
cd /tmp
tar -xf firmware.tar.gz
cd /tmp/linux-firmware-*

mv /lib/firmware /tmp/

#mkdir -p /lib/firmware/i915

rsync -av iwlwifi-*-72.ucode /lib/firmware/

# mele video
rsync -av i915/icl_dmc_ver1_09.bin /lib/firmware/i915/

# mele eth
rsync -av rtl_nic/rtl8168h-2.fw /lib/firmware/rtl_nic/

# usb wifi
rsync -av mediatek/mt7610u.bin  /lib/firmware/mediatek/

# bluetooth
rsync -av intel/ibt-19-0-4.sfi /lib/firmware/intel

find /lib/firmware/
mksquashfs /lib/firmware /efi/kernel/firmware

rm -rf /tmp/initrd
