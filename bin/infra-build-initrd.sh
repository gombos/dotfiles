#!/bin/bash

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

# customize busybox - maybe on gentoo
# https://git.alpinelinux.org/aports/log/main/busybox/busyboxconfig
# https://git.alpinelinux.org/aports/tree/main/busybox/APKBUILD
# https://git.busybox.net/busybox
# https://gitweb.gentoo.org/repo/gentoo.git/tree/sys-apps/busybox/busybox-1.35.0.ebuild

# Sizes - compressed: 1.5M
#busybox - 800M
#musl - 600M
#liblkid - 300M (needed by udev)
#udev - 600M
#udev-rules (lib/udev/*_id) - 300M

# steps to rebuild an alpine package - takes forever to check out the git repo
#  apk add sudo alpine-sdk
#  adduser -D build
#  addgroup build abuild
#  addgroup abuild root
#  echo 'build ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
#  su build
#  export PATH=$PATH:/sbin/

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

. /tmp/infra-env.sh

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

cd /
mkdir -p /efi /lib /tmp/dracut

apk upgrade
apk update

apk add dracut-modules --update-cache --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing --allow-untrusted  >/dev/null

# Temporal build dependencies
apk add git curl xz bzip2 alpine-sdk linux-headers >/dev/null

# Idea: instead of just going with the alpine default busybox, maybe build it from source, only the modules I need, might be able to save about 0.5M

# grab upstream dracut source
git clone https://github.com/dracutdevs/dracut.git && cd dracut

# pull in a few PRs

# udevadm over of blkid
curl https://patch-diff.githubusercontent.com/raw/dracutdevs/dracut/pull/2033.patch | git apply

git diff

# grab upstream modules only
rm -rf /usr/lib/dracut/modules.d && mv /dracut/modules.d /usr/lib/dracut/ # && rm -rf /dracut

# less is more :-), this is an extra layer to make sure systemd is not needed
rm -rf /usr/lib/dracut/modules.d/*systemd*
rm -rf /usr/lib/dracut/modules.d/*network*

# udev depends on libkmod
# rebuild libkmod without openssl lib (libkmod will be dependent on musl and libzstd)
wget https://mirrors.edge.kernel.org/pub/linux/utils/kernel/kmod/kmod-30.tar.xz
xz -d *.xz && tar -xf *.tar && cd kmod-30
./configure --prefix=/usr --bindir=/bin --sysconfdir=/etc --with-rootlibdir=/lib --disable-test-modules --disable-tools --disable-manpages
make
rm -rf /lib/libkmod.so* && make install && make clean 2>&1 > /dev/null
strip /lib/libkmod.so*

cd /

wget https://busybox.net/downloads/busybox-1.35.0.tar.bz2
bzip2 -d busybox-*.tar.bz2 && tar -xf busybox-*.tar && cd busybox-*
cp /tmp/busyboxconfig .config
make oldconfig
diff /tmp/busyboxconfig .config
make
strip ./busybox
mv ./busybox /bin/busybox
cd /
rm -rf busybox*

ls -la /bin/busybox
/bin/busybox

# Uninstall temporal build dependencies
apk del xz bzip2 alpine-sdk git curl >/dev/null

# Remove some files that can be be uninstalled becuase of package dependencies
rm /bin/findmnt /usr/bin/cpio
> /usr/sbin/dmsetup
> /bin/dmesg

# workaround - img-lib requires tar
> /bin/tar

cd /

# Idea: instead of just going with the alpine default busybox, maybe build it from source, only the modules I need, might be able to save about 0.5M

# TODO
# make module that mounts squashfs without initqueue
#rm -rf /sbin/udevd  /bin/udevadm
#> /sbin/udevd
#> /bin/udevadm

# todo - mount the modules file earlier instead of duplicating them
# this probably need to be done on udev stage (pre-mount is too late)

# to debug, add the following dracut modules
# kernel-modules shutdown terminfo debug

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

# busybox, udev-rules, base, fs-lib, rootfs-block, img-lib, dm, dmsquash-live

# ntfs3
cat > /tmp/ntfs3.rules << 'EOF'
SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="ntfs", ENV{ID_FS_TYPE}="ntfs3"
EOF

dracut --nofscks --force --no-hostonly --no-early-microcode --no-compress --reproducible --tmpdir /tmp/dracut --keep --no-kernel \
  --modules 'dmsquash-live busybox' \
  --include /tmp/infra-init.sh /lib/dracut/hooks/pre-pivot/01-init.sh \
  --include /usr/lib/dracut/modules.d/90kernel-modules/parse-kernel.sh /lib/dracut/hooks/cmdline/01-parse-kernel.sh \
  --include /tmp/ntfs3.rules /lib/udev/rules.d/ntfs3.rules \
  initrd.img $KERNEL

mv /tmp/dracut/dracut.*/initramfs /
cd /initramfs

# TODO
# need to specify root by HW ID /dev/sr0 instead of label and might need to preload isofs
#  rm -rf lib/udev/cdrom_id
#  rm -rf lib/udev/rules.d/60-cdrom_id.rules

# Clean some dracut info files
rm -rf usr/lib/dracut/build-parameter.txt
rm -rf usr/lib/dracut/dracut-*
rm -rf usr/lib/dracut/modules.txt

# when the initrd image contains the whole CD ISO - see https://github.com/livecd-tools/livecd-tools/blob/main/tools/livecd-iso-to-pxeboot.sh
rm -rf lib/dracut/hooks/pre-udev/30-dmsquash-liveiso-genrules.sh

# todo - ideally dm dracut module is not included instead of this hack
rm -rf lib/dracut/hooks/pre-udev/30-dm-pre-udev.sh
rm -rf lib/dracut/hooks/shutdown/25-dm-shutdown.sh
rm -rf lib/dracut/hooks/initqueue/timeout/99-rootfallback.sh
rm -rf lib/udev/rules.d/75-net-description.rules
rm -rf etc/udev/rules.d/11-dm.rules

rm -rf usr/sbin/dmsetup

# optimize - Remove empty (fake) binaries
find usr/bin usr/sbin -type f -empty -delete -print
rm -rf lib/dracut/need-initqueue

# just symlinks in alpine
rm -rf sbin/chroot
rm -rf bin/dmesg

rm -rf var/tmp
rm -rf root

rm -rf etc/fstab.empty
rm -rf etc/cmdline.d
rm -rf etc/ld.so.conf.d/libc.conf
rm -rf etc/ld.so.conf
rm -rf etc/group
rm -rf etc/mtab

# echo 'liveroot=$(getarg root=); rootok=1; wait_for_dev -n /dev/root; return 0' > lib/dracut/hooks/cmdline/30-parse-dmsquash-live.sh

# TODO - why is this needed ?
# without this file is still does not boot
# dmsquash-live-root still need to mount the squashfs that is inside .iso file

# TODO
# can we get rid of /sbin/udevd /bin/udevadm and use mdev or mdevd instead on alpine

rm sbin/switch_root && cp /sbin/switch_root sbin/

rm -rf lib/dracut/modules.txt lib/dracut/build-parameter.txt lib/dracut/dracut-*

apk add cpio gzip

rm -rf ./bin/busybox
rm -rf ./bin/gzip
rm -rf ./bin/tar
rm -rf ./bin/dmesg
rm -rf ./sbin/blkid

# Populate logs with the list of filenames inside initrd.img
find . -type f -exec ls -la {} \; | sort -k 5,5  -n -r

find .

mkdir -p /efi/kernel/
find . -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd.img
ls -lha /efi/kernel/initrd*.img

# Keep initramfs simple and do not require networking

# todo --debug --no-early-microcode --xz --keep --verbose --no-compress --no-kernel
# todo - interesting modules , usrmount, livenet, convertfs qemu qemu-net
# todo - use --no-kernel and mount modules early, write a module 00mountmodules or 01mountmodules

# include modules that might be reqired to find and mount modules file
# nls_iso8859_1 - mount vfat EFI partition if modules file is in EFI
# isofs - mount iso file if modules file is inside the iso
# ntfs - iso file itself might be stored on the ntfs filesystem
# ahci, uas (USB Attached SCSI), nvme - when booting on bare metal, to find the partition and filesystem

# todo - idea: break up initrd into 2 files - one with modules and one without modules, look into of the modules part can be conbined with the modules file
# find updates -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/updates.img

# shutdown - to help kexec
# terminfo - to debug

# todo - upstream - 00-btrfs.conf
# https://github.com/dracutdevs/dracut/commit/0402b3777b1c64bd716f588ff7457b905e98489d

apk del util-linux-misc dracut-modules squashfs-tools git util-linux-misc cpio >/dev/null

rm -rf /tmp
