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

if [ -f /etc/os-release ]; then
 . /etc/os-release
fi

. /tmp/infra-env.sh

if [ -z "$SCRIPTS" ]; then
  export SCRIPTS="/tmp"
fi

#D='--debug --verbose'

# customize busybox - maybe on gentoo
# https://git.alpinelinux.org/aports/log/main/busybox/busyboxconfig
# https://git.alpinelinux.org/aports/tree/main/busybox/APKBUILD
# https://git.busybox.net/busybox
# https://gitweb.gentoo.org/repo/gentoo.git/tree/sys-apps/busybox/busybox-1.35.0.ebuild

# Sizes - compressed: 1.5M
#busybox - 800M
#musl - 600M
#blkid - 400M
#udev - 600M
#udev-rules (lib/udev/*_id) - 300M
# TODO: kill blkid, udev anyways have blkid built in
# sudo udevadm test-builtin blkid

mkdir -p /efi /lib /tmp/dracut

  apk upgrade
  apk update

   # steps to rebuild an alpine package - takes forever to check out the git repo
#  apk add sudo alpine-sdk
#  adduser -D build
#  addgroup build abuild
#  addgroup abuild root
#  echo 'build ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
#  su build
#  export PATH=$PATH:/sbin/

  apk add dracut-modules --update-cache --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing --allow-untrusted
  apk add squashfs-tools git util-linux-misc

#  emerge -v sys-apps/busybox sys-fs/squashfs-tools dev-vcs/git sys-apps/util-linux sys-kernel/dracut

  # udev depends on libkmod, libkmod depends on crypto, crypto is biggest dependent library
  # rebuild libkmod without openssl lib
  apk add xz alpine-sdk
  wget https://mirrors.edge.kernel.org/pub/linux/utils/kernel/kmod/kmod-30.tar.xz
  xz -d *.xz
  tar -xf *.tar
  cd kmod-30
  ./configure --prefix=/usr --bindir=/bin --sysconfdir=/etc --with-rootlibdir=/lib --disable-test-modules --disable-tools --disable-manpages
  make

  rm -rf  /lib/libkmod.so*
  make install
  strip /lib/libkmod.so*
  # ldd /lib/libkmod.so* --> only musl and libzstd (no libblkid)
  apk del xz alpine-sdk

  # switch_root is buggy but it works on a basic scenario.. it does not maintain /run after switching root
  # some people might not need util-linux-misc but I DO

  #apk add build-base make # build base
  #apk add fts-dev kmod-dev pkgconfig # build dracut
  #apk add bash eudev coreutils blkid util-linux-misc # run dracut

  # TODO
  # remove dependency on eudev coreutils

  rm /bin/findmnt

# Idea: instead of just going with the alpine default busybox, maybe build it from source, only the modules I need, might be able to save about 0.5M

unsquashfs /efi/kernel/modules
mv squashfs-root /lib/modules

cd /

# build dracut from source
git clone https://github.com/dracutdevs/dracut.git && cd dracut

# pull in a PR
#git fetch origin refs/pull/1934/head:pr && git checkout pr

# build and install upstream
#bash -c "./configure --disable-documentation" && make 2>/dev/null && make install

# grab upstream modules only
rm -rf /usr/lib/dracut/modules.d && mv /dracut/modules.d /usr/lib/dracut/

# less is more :-), this is an extra layer to make sure systemd is not needed
rm -rf /usr/lib/dracut/modules.d/*systemd*

> /usr/sbin/dmsetup
rm -rf /usr/lib/systemd/systemd

# TODO
# make module that mounts squashfs without initqueue
#rm -rf /sbin/udevd  /bin/udevadm
#> /sbin/udevd
#> /bin/udevadm

# Remove the busybox version
# workaround to instruct dracut not to compress
rm -rf /usr/bin/cpio

# release optimizations
if [ -z "${D}" ]; then
  # fake to satisfy mandatory dependencies
  mv /bin/tar /tmp/
  mv /bin/gzip /tmp/

  > /bin/tar
  > /bin/gzip

  # Symlinks
  rm -rf /usr/sbin/rmmod
  > /usr/sbin/rmmod
fi

# todo - mount the modules file earlier instead of duplicating them
# this probably need to be done on udev stage (pre-mount is too late)

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

# busybox, udev-rules, base, fs-lib, rootfs-block, img-lib, dm, dmsquash-live
DRACUT_MODULES='dmsquash-live busybox'

if [ -n "${D}" ]; then
  DRACUT_MODULES="$DRACUT_MODULES debug"
fi

dracut --quiet --nofscks --force --no-hostonly --no-early-microcode --no-compress --reproducible --tmpdir /tmp/dracut --keep $D \
  --add-drivers 'autofs4 squashfs overlay nls_iso8859_1 isofs ntfs ahci nvme xhci_pci uas sdhci_acpi mmc_block ata_piix ata_generic pata_acpi cdrom sr_mod virtio_scsi' \
  --modules "$DRACUT_MODULES" \
  --include /tmp/infra-init.sh /lib/dracut/hooks/pre-pivot/01-init.sh \
  --include /usr/lib/dracut/modules.d/90kernel-modules/parse-kernel.sh /lib/dracut/hooks/cmdline/01-parse-kernel.sh \
  initrd.img $KERNEL

rm initrd.img

cd /tmp/dracut/dracut.*/initramfs

# TODO
# need to specify root by HW ID /dev/sr0 instead of label and might need to preload isofs
#  rm -rf lib/udev/cdrom_id
#  rm -rf lib/udev/rules.d/60-cdrom_id.rules


if [ -z "${D}" ]; then
  # Clean some dracut info files
  rm -rf usr/lib/dracut/build-parameter.txt
  rm -rf usr/lib/dracut/dracut-*
  rm -rf usr/lib/dracut/modules.txt

  # when the initrd image contains the whole CD ISO - see https://github.com/livecd-tools/livecd-tools/blob/main/tools/livecd-iso-to-pxeboot.sh
  rm -rf lib/dracut/hooks/pre-udev/30-dmsquash-liveiso-genrules.sh

  # todo - ideally dm dracut module is not included instead of this hack
  rm -rf usr/lib/dracut/hooks/pre-udev/30-dm-pre-udev.sh
  rm -rf usr/lib/dracut/hooks/shutdown/25-dm-shutdown.sh
  rm -rf usr/sbin/dmsetup
  rm -rf lib/modules/$KERNEL/kernel/drivers/md

  # optimize - Remove empty (fake) binaries
  find usr/bin usr/sbin -type f -empty -delete -print

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
fi

mv /tmp/tar /bin/
mv /tmp/gzip /bin/

#rm -rf ./lib/dracut/hooks/shutdown/25-dm-shutdown.sh ./lib/dracut/hooks/initqueue/timeout/99-rootfallback.sh  ./lib/udev/rules.d/75-net-description.rules  ./lib/dracut/hooks/cmdline/31-parse-iso-scan.sh  ./lib/dracut/hooks/pre-udev/30-dm-pre-udev.sh ./lib/dracut/hooks/shutdown/25-dm-shutdown.sh
#rm -rf ./etc/udev/rules.d/11-dm.rules ./sbin/iso-scan

# echo 'liveroot=$(getarg root=); rootok=1; wait_for_dev -n /dev/root; return 0' > lib/dracut/hooks/cmdline/30-parse-dmsquash-live.sh

# TODO - why is this needed ?
# without this file is still does not boot
# rm -rf sbin/dmsquash-live-root

# TODO
# can we get rid of /sbin/udevd /bin/udevadm and use mdev or mdevd instead on alpine

# blkid bugs might be able to worked around, but fs-lib dracut module needs some serious look -
# https://github.com/dracutdevs/dracut/pull/1956 .. this change might not be enough, lets debug more
# TODO eliminate blkid, it brings in not only a new bin, but also libblkid.so.1.1.0 (almost 0.4M)
rm sbin/blkid && cp /sbin/blkid sbin/
rm sbin/switch_root && cp /sbin/switch_root sbin/

rm -rf lib/dracut/modules.txt lib/dracut/build-parameter.txt lib/dracut/dracut-*

if [ "$ID" = "arch" ]; then
  pacman --noconfirm -Sy cpio && yes | pacman  -Scc
elif [ "$ID" = "alpine" ]; then
  apk add cpio
else
  apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 cpio
fi

find lib/modules/ -print0 | cpio --null --create --format=newc | gzip --best > /efi/kernel/initrd_modules.img
rm -rf lib/modules

# Populate logs with the list of filenames inside initrd.img
find . -type f -exec ls -la {} \; | sort -k 5,5  -n -r

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

rm -rf /tmp/initrd /tmp/cleanup /tmp/updates /tmp/dracut
