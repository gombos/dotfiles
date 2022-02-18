# Requirements:
# - Does not need /home
# - Does not need /etc or /usr rw
# - Does not need to run as root or sudo
# - Does not use the network

# initramfs and most tools generating initramfs are designed to be host specific

# In general each kernel version will have to have its own initramfs
# but with a bit of work it is possible to make initramfs generic (not HW or host SW specific)

# https://fai-project.org/
# This is also way more powerful (systemd volatile)

# A read-only /etc is increasingly common on embedded devices.
# A rarely-changing /etc is also increasingly common on desktop and server installations, with files like /etc/mtab and /etc/resolv.conf located on another filesystem and symbolically linked in /etc (so that files in /etc need to be modified when installing software or when the computer's configuration changes, but not when mounting a USB drive or connecting in a laptop to a different network).
# The emerging standard is to have a tmpfs filesystem mounted on /run and symbolic links in /etc like

# Create a temporary file called rdexec and copy it into initramfs to be executed
# This solution only requires dropping one single hook file into initramfs
# This argument allows calling out to EFI parition from within initramfs to execute arbitrary code
# Future goal - instead of executing arbitrary code, try to just create additional files and drop them
# For user management switch to homectl and portable home directories

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

cd /tmp

. ./infra-env.sh

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

mkdir -p /efi

export DEBIAN_FRONTEND=noninteractive

apt-get update -y -qq -o Dpkg::Use-Pty=0
apt-get upgrade -y -qq -o Dpkg::Use-Pty=0

# TODO - remove bash dependency

apt-get --reinstall install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-image-$KERNEL

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-modules-extra-$KERNEL

# Build custom kernel that has isofs built in
#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 build-essential libncurses5-dev gcc libssl-dev bc libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf fakeroot

#apt-get build-dep -y linux-image-$KERNEL
#apt-get build-dep -y linux-image-unsigned-$KERNEL
#apt-get source linux-image-unsigned-$KERNEL

#cd linux-5.13.0
#make oldconfig
#scripts/diffconfig .config{.old,}
#make deb-pkg

# dracut/initrd
# unzip wget ca-certificates git - get the release
# coreutils - stat
# mount - umount

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 \
  cpio build-essential libkmod-dev pkg-config \
  dash udev coreutils mount \
  unzip wget ca-certificates git

# fake to satisfy mandatory dependencies
touch /usr/sbin/dmsetup

# dracut official release
#rm -rf 055.zip dracut-055
#wget --no-verbose --no-check-certificate https://github.com/dracutdevs/dracut/archive/refs/tags/055.zip
#unzip -q 055.zip
#cd dracut-055

#git clone https://github.com/dracutdevs/dracut.git dracutdir

# swith to my branch for now
git clone https://github.com/LaszloGombos/dracut.git dracutdir

# patch dracut
#cp -av dracut/* dracutdir

# build dracut
cd dracutdir
./configure --disable-documentation
make 2>/dev/null
make install
cd ..

mkdir -p /tmp/dracut
mkdir -p /efi/kernel

# todo - mount the modules file earlier instead of duplicating them
# this probably need to be done on udev stage (pre-mount is too late)

# todo - remove base dependency after

# to debug, add the following dracut modules
# kernel-modules shutdown terminfo debug

# dracut-systemd adds about 4MB (compressed)

# bare minimium modules "base rootfs-block"

#--mount "/run/media/efi/kernel/modules /usr/lib/modules squashfs ro,noexec,nosuid,nodev" \

# filesystem kernel modules
# nls_XX - to mount vfat
# isofs - to find root within iso file
# autofs4 - systemd will try to load this (maybe because of fstab)

# storage kernel modules
# ahci - for SATA devices on modern AHCI controllers
# nvme - for NVME (M.2, PCI-E) devices
# xhci_pci, uas - usb
# sdhci_acpi, mmc_block - mmc

# sd_mod for all SCSI, SATA, and PATA (IDE) devices
# ehci_pci and usb_storage for USB storage devices
# virtio_blk and virtio_pci for QEMU/KVM VMs using VirtIO for storage
# ehci_pci - USB 2.0 storage devices

dracut --nofscks --force --no-hostonly --no-early-microcode --no-compress --reproducible --tmpdir /tmp/dracut --keep \
  --add-drivers 'nls_iso8859_1 isofs ntfs ahci nvme xhci_pci uas sdhci_acpi mmc_block ata_piix ata_generic pata_acpi cdrom sr_mod virtio_scsi' \
  --modules 'dmsquash-live' \
  --include /tmp/infra-init.sh  /usr/lib/dracut/hooks/pre-pivot/00-init.sh \
  --aggresive-strip \
  initrd.img $KERNEL

rm initrd.img

# Populate logs with the list of filenames
cd /tmp/dracut/dracut.*/initramfs

# Clean some dracut info files
rm -rf usr/lib/dracut/build-parameter.txt
rm -rf usr/lib/dracut/dracut-*
rm -rf usr/lib/dracut/modules.txt

# when the initrd image contains the whole CD ISO - see https://github.com/livecd-tools/livecd-tools/blob/main/tools/livecd-iso-to-pxeboot.sh
rm -rf usr/lib/dracut/hooks/pre-udev/30-dmsquash-liveiso-genrules.sh

# todo - ideally dm dracut module is not included instead of this hack
rm -rf usr/lib/dracut/hooks/pre-udev/30-dm-pre-udev.sh
rm -rf usr/lib/dracut/hooks/shutdown/25-dm-shutdown.sh
rm -rf usr/sbin/dmsetup
rm -rf usr/lib/modules/$KERNEL/kernel/drivers/md

# optimize - this does not remove the dependent libraries
rm -rf usr/sbin/chroot
rm -rf usr/bin/dmesg
rm -rf usr/bin/chmod

#rm -rf usr/sbin/rmmod
#rm -rf usr/bin/uname
#rm -rf usr/bin/kmod

#rm -rf usr/bin/tar
#rm -rf usr/bin/cpio
#rm -rf usr/bin/bzip2
#rm -rf usr/bin/gzip

#rm -rf etc/cmdline.d
rm -rf etc/fstab.empty

#rm -rf etc/conf.d
#rm -rf etc/ld.so.conf
#rm -rf etc/ld.so.conf.d/libc.conf

#rm -rf var/tmp

#rm -rf root

# kexec can only handle one initrd file
#find usr/lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/modules.img
#rm -rf usr/lib/modules

#mkdir updates
#cd updates

#mkdir -p usr/bin/
#mkdir -p etc/systemd/system/basic.target.wants/ usr/lib/systemd/system/

# cp /tmp/dmsquash-live-root.sh sbin/dmsquash-live-root

#ln -sf /lib/systemd/system/boot.service etc/systemd/system/basic.target.wants/boot.service

#cd ..

# list files
find .

find . -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd.img

ls -lha /efi/kernel/initrd.img

#mksquashfs . /efi/kernel/initrd.img

cd /tmp
rm -rf /tmp/dracut

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 linux-headers-$KERNEL apt-utils

if ! [ -z "${NVIDIA}" ]; then
  apt-get --reinstall install -y nvidia-driver-${NVIDIA}
fi

# bootloader
# mtools - efi iso boot

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 \
  grub-efi-amd64-bin grub-pc-bin grub2-common \
  syslinux-common \
  isolinux mtools dosfstools

# kernel binary
mkdir -p /efi/kernel
cp -r /boot/vmlinuz-$KERNEL /efi/kernel/vmlinuz

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

grub-mkstandalone --format=i386-pc    --output="$LEGACYDIR/core.img" --install-modules="$GRUB_MODULES biosdisk ntldr"  --modules="$GRUB_MODULES biosdisk" --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_bios.cfg"
grub-mkstandalone --format x86_64-efi --output="/efi/EFI/BOOT/bootx64.efi"  --install-modules="$GRUB_MODULES"          --modules="$GRUB_MODULES"          --locales="" --themes="" --fonts="" "/boot/grub/grub.cfg=/tmp/grub_efi.cfg"

cp /usr/lib/grub/i386-pc/boot_hybrid.img $ISODIR/

# bios boot for booting from a CD-ROM drive
cat /usr/lib/grub/i386-pc/cdboot.img $LEGACYDIR/core.img > $ISODIR/bios.img

# EFI boot partition - FAT16 disk image
dd if=/dev/zero of=$ISODIR/efiboot.img bs=1M count=10 && \
mkfs.vfat $ISODIR/efiboot.img && \
LC_CTYPE=C mmd -i $ISODIR/efiboot.img efi efi/boot && \
LC_CTYPE=C mcopy -i $ISODIR/efiboot.img /efi/EFI/BOOT/bootx64.efi ::efi/boot/

# Make sure we have all the required modules built
$SCRIPTS/infra-install-vmware-workstation-modules.sh

rm -rf /tmp/initrd
mkdir -p /tmp/initrd
cd /tmp/initrd

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

# Keep initramfs simple and do not require networking

# todo --debug --no-early-microcode --xz --keep --verbose --no-compress --no-kernel
# todo - interesting modules , usrmount, livenet, convertfs qemu qemu-net
# todo - use --no-kernel and mount modules early, write a module 00mountmodules or 01mountmodules

# include modules that might be reqired to find and mount modules file
# nls_iso8859_1 - mount vfat EFI partition if modules file is in EFI
# isofs - mount iso file if modules file is inside the iso
# ntfs - iso file itself might be stored on the ntfs filesystem
# ahci, uas (USB Attached SCSI), nvme - when booting on bare metal, to find the partition and filesystem

# Tests:
# - ahci: boot from ata drive attached to a montherboard
# - uas: boot from usb external drive
# - nvme: boot from nvme drive

# todo - remove dmsquash-live-ntfs dracut as anyways ntfs module is included and that should be enough - test it after removing
# todo - idea: break up initrd into 2 files - one with modules and one without modules, look into of the modules part can be conbined with the modules file

# --modules 'base bash dm dmsquash-live dmsquash-live-ntfs dracut-systemd fs-lib img-lib rootfs-block shutdown systemd systemd-initrd terminfo udev-rules'

# shutdown - to help kexec
# terminfo - to debug

# todo - upstream - 00-btrfs.conf
# https://github.com/dracutdevs/dracut/commit/0402b3777b1c64bd716f588ff7457b905e98489d

# Uncompress
#gunzip -c -S img initrd.img | cpio -idmv 2>/dev/null

#rm initrd.img

#mkdir /tmp/updates
#cd /tmp/updates

#mkdir -p usr/bin/ etc/systemd/system/basic.target.wants/ usr/lib/systemd/system/
#cp /tmp/infra-init.sh usr/bin/

#cp /tmp/*.service usr/lib/systemd/system/
#ln -sf /lib/systemd/system/boot.service etc/systemd/system/basic.target.wants/boot.service

#cd /tmp/
#find updates -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/updates.img

#find /usr/lib/modules/ -print0 | cpio --null --create --format=newc | gzip --fast > /efi/kernel/modules.img

#apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 busybox zstd

apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 squashfs-tools

# try ot install busybox on rootfs or pick another compression algorithm that kmod supports
#find /usr/lib/modules/ -name '*.ko' -exec zstd {} \;
#find /usr/lib/modules/ -name '*.ko' -delete
# busybox depmod

#find /usr/lib/modules

mksquashfs /usr/lib/modules /efi/kernel/modules

rm -rf /tmp/initrd /tmp/cleanup /tmp/updates

# Populate logs with the list of filenames
#find /efi

# use syslinux only for booting legacy/non-ufi systems - for uefi system, no need to introduce an extra complexity into booting
