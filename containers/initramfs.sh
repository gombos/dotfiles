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

