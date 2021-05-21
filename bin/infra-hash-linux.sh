#!/bin/bash

mnt-linux
cd $MNTDIR/linux/linux

sudo find ./ -mount -type f -exec md5sum "{}" + | sort -k2 > ~/.dotfiles/infra/linux.chk
sudo find ./ -mount -type l -exec ls -lQ {} \; | cut -d\" -f2-4 | sort >> ~/.dotfiles/infra/linux.chk
sudo find ./ -mount -type d | sort >> ~/.dotfiles/infra/linux.chk

mnt-efi
cd /$MNTDIR/efi
sudo find EFI/BOOT tce grub kernel -type f -exec md5sum "{}" + | sort -k2 > ~/.dotfiles/infra/efi.chk
