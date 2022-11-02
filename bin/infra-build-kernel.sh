#!/bin/bash

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

cd /tmp

. ./infra-env.sh

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

mkdir -p /efi/kernel

export DEBIAN_FRONTEND=noninteractive

# enable getting source debs
sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list

apt-get update -y -qq -o Dpkg::Use-Pty=0
apt-get upgrade -y -qq -o Dpkg::Use-Pty=0

# TODO - get kernel without apt, so that I can use any distro as a base, including alpine, do not rely on package manager
# first step - just download .deb manually and install

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0  apt-utils ca-certificates git fakeroot gzip dracut-core wget linux-base sudo libelf1

#apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-$KERNEL
#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-modules-extra-$KERNEL linux-headers-$KERNEL

wget https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh && chmod +x ubuntu-mainline-kernel.sh

sudo ./ubuntu-mainline-kernel.sh -nc -ns --yes -d -p . -i $KERNEL
export KERNEL=$(dpkg -l | grep linux-modules | head -1  | cut -d\- -f3- | cut -d ' ' -f1)

# Prepare to compile my own kernel
#apt-get build-dep -y -o Dpkg::Use-Pty=0 linux-image-unsigned-$KERNEL
#apt-get source -y -o Dpkg::Use-Pty=0 linux-image-unsigned-$KERNEL
#cd linux-*5.15.0
#chmod a+x debian/rules
#chmod a+x debian/scripts/*
#chmod a+x debian/scripts/misc/*
#LANG=C fakeroot debian/rules clean
#LANG=C fakeroot debian/rules binary

if ! [ -z "${NVIDIA}" ]; then
  apt-get --reinstall install -y nvidia-driver-${NVIDIA}
fi

# kernel binary
ls -la /boot

cp -r /boot/vmlinuz-$KERNEL /efi/kernel/vmlinuz

# Make sure we have all the required modules built
$SCRIPTS/infra-install-vmware-workstation-modules.sh

#find /usr/lib/modules/ -print0 | cpio --null --create --format=newc | gzip --fast > /efi/kernel/modules.img

#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 busybox zstd

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 squashfs-tools

# try ot install busybox on rootfs or pick another compression algorithm that kmod supports
#find /usr/lib/modules/ -name '*.ko' -exec zstd {} \;
#find /usr/lib/modules/ -name '*.ko' -delete
# busybox depmod

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 cpio

mkdir /tmp/dracut

dracut --quiet --nofscks --force --no-hostonly --no-early-microcode --no-compress --tmpdir /tmp/dracut --keep --kernel-only \
  --add-drivers 'autofs4 overlay nls_iso8859_1 isofs ntfs ahci nvme xhci_pci uas sdhci_acpi mmc_block pata_acpi virtio_scsi usbhid hid_generic hid' \
  --modules 'rootfs-block' \
  initrd.img $KERNEL

cd  /tmp/dracut/dracut.*/initramfs/

find lib/modules/ -name "*.ko"

find lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd_modules.img

cd /tmp

ls -lha /efi/kernel/initrd_modules.img

mksquashfs /usr/lib/modules /efi/kernel/modules
rm -rf /tmp/initrd

# Build custom kernel that has isofs built in
#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 build-essential libncurses5-dev gcc libssl-dev bc libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf fakeroot

#apt-get build-dep -y linux-image-$KERNEL
#apt-get build-dep -y linux-image-unsigned-$KERNEL
#apt-get source linux-image-unsigned-$KERNEL

#cd linux
#make oldconfig
#scripts/diffconfig .config{.old,}
#make deb-pkg

