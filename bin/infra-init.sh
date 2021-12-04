#!/bin/bash

# first boot of a new instance, run all the “per-instance” configuration

# Warning: error in this file will likely lead to failure to boot

# Idea: detect if cloud-init is installed in the image and run the script during later in the boot phase
# Any of thid is needed when a container is initialized ?
# For LXC-like containers, ssh keys are needed
# also - thsi is a useful way to run containers - https://medium.com/swlh/docker-and-systemd-381dfd7e4628

# Consider only testing/changing this file in a development environment with access to console

# This script logs to /run/initramfs/rdexec.out
# Determine where this script is called from - either as a dracut hook or as a cloud-init phase or 'docker run'

# This script is optional for containers, that are not "booted" and do not initialize systemd. Keep it that way

# cloud-init does similar things

# Do not change /usr to allow ro mount
# Ideally only make changes in /var
# To avoid manipulating /etc use kernel arguments when possible
# Instead of changing existing files, try to just add new files
# Keep changing in /run

# Configuration 1 - OverlayRoot
# Rootfs is mounted ro and EFI partition is mounted as ro to customize rootfs overlay
# /run can be used to create new files and directories that are not persistent between boots
# Symlink /etc to /run when possible - use relative links. This will allow editing these files even if etc itself is mounted read-only

# Input:
# - environment variables, /proc filesystem, including /proc/cmdline
# - current directory is set to where the rd.exec file is located
# - $mp points to EFI partition root
# - $NEWROOT points to root filesystem
# - all changes to root filesystem are made in ram (overlayroot)

# Autodetect the environment
# Disks - /dev/disks, /proc/partitions
# HW - /proc/cpuinfo
# Grub - /proc/cmdline
# Network - DHCP
# rootfs version

mkdir -p /run/media
chown 0:27 /run/media
chmod g+w /run/media

R="$NEWROOT"

# todo - implement command line argument to disable running this script in initrd
# todo - split this into etc/fstab generator and into a an init systemd rc.local script that can be executed without reexecuting initrd

# initramfs
# mount modules from ESP
# populate /etc/fstab

mkdir -p $NEWROOT/boot

if [[ -e /dev/disk/by-label/EFI ]]; then
  mkdir -p /run/media/efi
  mount -o ro,noexec,nosuid,nodev /dev/disk/by-label/EFI /run/media/efi
  mount --bind /run/media/efi $NEWROOT/boot

  rm -rf $NEWROOT/usr/lib/modules /usr/lib/modules
  mkdir -p $NEWROOT/usr/lib/modules
  mount /run/media/efi/kernel/modules $NEWROOT/usr/lib/modules
  ln -sf $NEWROOT/usr/lib/modules /usr/lib/
else
  rm -rf $NEWROOT/usr/lib/modules /usr/lib/modules
  mkdir -p $NEWROOT/usr/lib/modules
  mount /run/initramfs/live/kernel/modules $NEWROOT/usr/lib/modules
  mount --bind /run/initramfs/live $NEWROOT/boot
fi
