#!/bin/sh

mkdir -p /efi/kernel

# kernel binary
ls -la /boot

#cp -r /boot/vmlinuz-$KERNEL /efi/kernel/vmlinuz

#apt-get update -y -qq && apt-get upgrade -y -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 squashfs-tools  cpio
apk add squashfs-tools  cpio

mkdir /tmp/dracut

#dracut --quiet --nofscks --force --no-hostonly --no-early-microcode --no-compress --tmpdir /tmp/dracut --keep --kernel-only \
#  --add-drivers 'autofs4 overlay nls_iso8859_1 isofs ntfs ahci nvme xhci_pci uas sdhci_acpi mmc_block pata_acpi virtio_scsi usbhid hid_generic hid' \
#  --modules 'rootfs-block' \
#  initrd.img $KERNEL

#cd  /tmp/dracut/dracut.*/initramfs/

#find lib/modules/ -name "*.ko"

#find lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd_modules.img
ls -lha /efi/kernel/initrd_modules.img

cd /tmp

mksquashfs /usr/lib/modules /efi/kernel/modules
rm -rf /tmp/initrd
