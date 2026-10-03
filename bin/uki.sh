#!/usr/bin/env bash

sudo cp /efi/EFI/BOOT/BOOTX64.EFI /tmp/
sudo chmod 777 /tmp/BOOTX64.EFI

uki-dracut.sh

sudo cp /tmp/BOOTX64.NEW.EFI /efi/EFI/BOOT/BOOTX64.EFI
