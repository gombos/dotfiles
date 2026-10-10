#!/usr/bin/env bash

sudo mount /efi
sudo cp /efi/EFI/BOOT/BOOTX64.EFI /tmp/
sudo chmod 777 /tmp/BOOTX64.EFI

uki-dracut.sh

# report new size
ls -sh /tmp/BOOTX64.NEW.EFI
sudo cp /tmp/BOOTX64.NEW.EFI /efi/EFI/BOOT/BOOTX64.EFI

# vfat, do not corrept, clean umount
sudo umount /efi
