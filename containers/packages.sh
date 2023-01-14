#!/bin/sh

# kernel
#apk add linux-virt

apk add losetup gummiboot dosfstools mtools

# dracut
apk add dracut --update-cache --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing --allow-untrusted

# Uninstall most mkinitfs files. mkinitfs gets pulled in by linux-virt
rm -rf /sbin/mkinitfs /usr/share/mkinitfs /etc/mkinitfs /boot/initramfs-*

ln -sf /boot/vmlinuz-virt /boot/vmlinuz-$(cd /lib/modules; ls -1 | tail -1)

# common
apk add \
    btrfs-progs cryptsetup dash dmraid mdadm sed lvm2 make sudo e2fsprogs parted bzip2 pigz procps kbd busybox git grep binutils cpio

# common - but distro specific name
apk add partx gpg multipath-tools openssh squashfs-tools qemu-img qemu-system-x86_64 sfdisk ntfs-3g xz xorriso ovmf

# networking
apk add nfs-utils libnfsidmap dhclient open-iscsi nbd curl

# btrfs - btrfs-progs - btrfs
# crypt - cryptsetup - crypt
# dash - dash - dash
# dmraid - dmraid, partx - dmraid
# gpg - gpg - crypt-gpg
# mdadm - mdadm, sed, partx - mdraid # sed: bad regex '(RUN|IMPORT\{program\})\+?="[[:alpha:]': Missing ']'
# lvm - lvm2 - lvm, lvmmerge, lvmthinpool-monitor
# multipath - multipath-tools, partx - multipath
# openssh - openssh, dracut-modules-network - ssh-client
# squashfs - squashfs-tools - squash

# RUN apk add networkmanager

# additional dependencies to run tests for networking
# RUN apk add qemu-block-nfs qemu-modules

cp /sbin/poweroff /sbin/shutdown
cp /usr/bin/dash /bin/dash
cp /bin/sh /usr/bin/sh
