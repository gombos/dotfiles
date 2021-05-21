#!/bin/sh

cd /

if [ -z "$RELEASE" ]; then
RELEASE=focal
fi

if [ -z "$KERNEL" ]; then
KERNEL="5.4.0-52-generic"
fi

# ---- efi

mkdir -p efi/kernel
rsync -av boot/vmlinuz-$KERNEL efi/kernel/vmlinuz

install_my_package grub-efi-amd64-bin
install_my_package grub-pc-bin
rsync -av usr/lib/grub efi/

