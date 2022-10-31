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
apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-$KERNEL
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-modules-extra-$KERNEL
apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-headers-$KERNEL apt-utils ca-certificates git fakeroot rsync gzip dracut-core

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

read -r -d '' VAR << EOM
drivers/ata/ahci.ko
drivers/ata/libahci.ko
drivers/ata/pata_acpi.ko
drivers/nvme/host/nvme.ko
drivers/nvme/host/nvme-core.ko
drivers/usb/host/xhci-pci.ko
drivers/usb/host/xhci-pci-renesas.ko
drivers/usb/storage/uas.ko
drivers/usb/storage/usb-storage.ko
drivers/mmc/host/sdhci-acpi.ko
drivers/mmc/host/sdhci.ko
drivers/mmc/core/mmc_block.ko
drivers/scsi/virtio_scsi.ko
lib/crc64.ko
lib/libcrc32c.ko
lib/raid6/raid6_pq.ko
crypto/xor.ko
crypto/async_tx/async_tx.ko
crypto/async_tx/async_xor.ko
crypto/async_tx/async_pq.ko
crypto/async_tx/async_memcpy.ko
crypto/async_tx/async_raid6_recov.ko
crypto/crc32_generic.ko
fs/dlm/dlm.ko
fs/isofs/isofs.ko
fs/overlayfs/overlay.ko
fs/autofs/autofs4.ko
fs/nls/nls_iso8859-1.ko
fs/ntfs/ntfs.ko
arch/x86/crypto/crc32-pclmul.ko
EOM

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 cpio

#mkdir /tmp/m
#while IFS= read -r line ; do rsync -Rav /lib/modules/$KERNEL/kernel/$line /tmp/m ; done <<< "$VAR"
while IFS= read -r line ; do ls -la  /lib/modules/$KERNEL/kernel/$line  ; done <<< "$VAR"
#cd /tmp/m && find lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd_modules.img && cd -

mkdir /tmp/dracut

dracut --quiet --nofscks --force --no-hostonly --no-early-microcode --no-compress --tmpdir /tmp/dracut --keep \
  --add-drivers 'autofs4 overlay nls_iso8859_1 isofs ntfs ahci nvme xhci_pci uas sdhci_acpi mmc_block pata_acpi virtio_scsi' \
  --modules 'rootfs-block' \
  initrd.img $KERNEL

mv /tmp/dracut/dracut.*/initramfs /
cd /initramfs

find lib/modules/

find lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd_modules.img

cd /tmp

ls -lha /efi/kernel/initrd_modules.img

mksquashfs /usr/lib/modules /efi/kernel/modules
rm -rf /tmp/initrd /tmp/cleanup /tmp/updates

# Build custom kernel that has isofs built in
#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 build-essential libncurses5-dev gcc libssl-dev bc libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf fakeroot

#apt-get build-dep -y linux-image-$KERNEL
#apt-get build-dep -y linux-image-unsigned-$KERNEL
#apt-get source linux-image-unsigned-$KERNEL

#cd linux
#make oldconfig
#scripts/diffconfig .config{.old,}
#make deb-pkg

# bootloader
# mtools - efi iso boot

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 \
  grub-efi-amd64-bin grub-pc-bin grub2-common \
  syslinux-common \
  isolinux mtools dosfstools wget

# for grub root variable is set to memdisk initially
# grub_cmdpath is the location from which core.img was loaded as an absolute directory name

# grub efi binary
mkdir -p /efi/EFI/BOOT/
cp /tmp/grub.cfg /efi/EFI/BOOT/

# use regexp to remove path part to determine the root
cat > /tmp/grub_efi.cfg << EOF
regexp --set base "(.*)/" \$cmdpath
regexp --set base "(.*)/" \$base
set root=\$base
configfile \$cmdpath/grub.cfg
EOF

cat > /tmp/grub_bios.cfg << EOF
prefix=
root=\$cmdpath
configfile \$cmdpath/EFI/BOOT/grub.cfg
EOF

LEGACYDIR="/efi/syslinux"
ISODIR="/efi/isolinux"
mkdir -p $LEGACYDIR
mkdir -p $ISODIR

# syslinux binary
cp /usr/lib/syslinux/mbr/gptmbr.bin $LEGACYDIR
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 $LEGACYDIR

# grub pc binary
cp -r /usr/lib/grub/i386-pc/lnxboot.img $LEGACYDIR/

# syslinux config - chainload grub
cat > $LEGACYDIR/syslinux.cfg <<EOF
DEFAULT grub
LABEL grub
 LINUX lnxboot.img
 INITRD core.img
EOF

# normal - loaded by default
# part_msdos part_gpt - mbr and gpt partition table support
# fat ext2 ntfs iso9660 hfsplus - search by fs labels and read files from fs
# linux - boot linux kernel
# linux16 - boot linux kernel 16 bit for netboot-xyz
# ntldr - boot windows
# loadenv - read andd write grub file used for boot once configuration
# test - conditionals in grub config file
# regexp - regexp, used to remove path part from a variable
# smbios - detect motherboard ID
# loopback - boot iso files
# chain - chain boot
# search - find partitions (by label or uuid, but no suport for part_label)

# configfile - is this really needed

# minicmd ls cat - interactive debug in grub shell

GRUB_MODULES="normal part_msdos part_gpt fat ext2 iso9660 ntfs hfsplus linux linux16 loadenv test regexp smbios loopback chain search configfile minicmd ls cat"

# for more control, consider just invoking grub-mkimage directly
# grub-mkstandalone just a wrapper on top of grub-mkimage

grub-mkstandalone --format=i386-pc --output="$LEGACYDIR/core.img" --install-modules="$GRUB_MODULES biosdisk ntldr" --modules="$GRUB_MODULES biosdisk" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_bios.cfg"
grub-mkstandalone --format=x86_64-efi --output="/efi/EFI/BOOT/bootx64.efi" --install-modules="$GRUB_MODULES linuxefi" --modules="$GRUB_MODULES linuxefi" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_efi.cfg"

cp /usr/lib/grub/i386-pc/boot_hybrid.img $ISODIR/

# bios boot for booting from a CD-ROM drive
cat /usr/lib/grub/i386-pc/cdboot.img $LEGACYDIR/core.img > $ISODIR/bios.img

# EFI boot partition - FAT16 disk image
dd if=/dev/zero of=$ISODIR/efiboot.img bs=1M count=10 && \
mkfs.vfat $ISODIR/efiboot.img && \
LC_CTYPE=C mmd -i $ISODIR/efiboot.img efi efi/boot && \
LC_CTYPE=C mcopy -i $ISODIR/efiboot.img /efi/EFI/BOOT/bootx64.efi ::efi/boot/

# TCE binary
mkdir -p /efi/tce
mkdir -p /efi/tce/optional
wget --no-check-certificate --no-verbose https://distro.ibiblio.org/tinycorelinux/12.x/x86_64/release/CorePure64-current.iso -O tce.iso
wget --no-verbose http://www.tinycorelinux.net/12.x/x86_64/tcz/openssl-1.1.1.tcz
wget --no-verbose http://www.tinycorelinux.net/12.x/x86_64/tcz/openssh.tcz
mv tce.iso /efi/tce
mv openssh*.tcz openssl*.tcz  /efi/tce/optional/
echo "openssl-1.1.1.tcz " >> /efi/tce/onboot.lst
echo "openssh.tcz" >> /efi/tce/onboot.lst
mkdir -p tce/opt
cd tce
echo "opt" > opt/.filetool.lst

cat > opt/bootsync.sh << 'EOF'
#!/bin/sh
# runs at boot
touch /usr/local/etc/ssh/sshd_config
sed -ri "s/^tc:[^:]*:(.*)/tc:\$6\$3fjvzQUNxD1lLUSe\$6VQt9RROteCnjVX1khTxTrorY2QiJMvLLuoREXwJX2BwNJRiEA5WTer1SlQQ7xNd\.dGTCfx\.KzBN6QmynSlvL\/:\1/" etc/shadow
/usr/local/etc/init.d/openssh start &
EOF

chmod +x opt/bootsync.sh

tar -czvf /efi/tce/mydata.tgz opt
cd ..

# netboot-xyz
wget --no-verbose --no-check-certificate https://boot.netboot.xyz/ipxe/netboot.xyz.lkrn
wget --no-verbose --no-check-certificate https://boot.netboot.xyz/ipxe/netboot.xyz.efi
mkdir -p /efi/netboot
mv netboot.xyz* /efi/netboot/
