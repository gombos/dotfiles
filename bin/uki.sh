#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash cpio dracut systemdUkify

sudo cp /efi/EFI/BOOT/BOOTX64.EFI /tmp/
sudo chmod 777 /tmp/BOOTX64.EFI
objcopy -O binary -j .linux /tmp/BOOTX64.EFI /tmp/kernel

dracut -vv --no-hostonly --force -m 'bash rootfs-block kernel-modules kernel-network-modules kernel-modules-extra qemu virtfs virtiofs shutdown overlayfs' --add-drivers "crc32c_intel crct10dif_pclmul evdev irqbypass nft_chain_nat sha256_ssse3 vsock xfrm_user xt_MASQUERADE xt_addrtype xt_connmark xt_conntrack xt_mark" /tmp/initrd

ukify build --linux=/tmp/kernel --initrd=/tmp/initrd --cmdline="root=LABEL=root ro rd.driver.pre=sd_mod rd.driver.pre=virtio_scsi" --output=/tmp/BOOTX64.NEW.EFI
sudo cp /tmp/BOOTX64.NEW.EFI /efi/EFI/BOOT/BOOTX64.EFI
