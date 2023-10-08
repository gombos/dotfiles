if ! [ -z "$REPO" ]; then
  cp $REPO/bin/* /tmp/
  cp $REPO/packages/* /tmp/
  cd /tmp
fi

mkdir /tmp/dracut

apk upgrade
apk update

apk add dracut-modules squashfs-tools

# --update-cache --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing --allow-untrusted  >/dev/null

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

mv /lib/firmware /tmp/
mkdir -p /lib/firmware
cp -a /tmp/firmware/iwlwifi-*-72.ucode /lib/firmware/
cp -a /tmp/firmware/i915 /lib/firmware/
find /lib/firmware/

mksquashfs /lib/firmware /efi/kernel/firmware
rm -rf /tmp/initrd

find /efi/kernel
ls -lRa /efi/kernel

