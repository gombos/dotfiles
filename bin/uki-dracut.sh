#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash cpio dracut systemdUkify

objcopy -O binary -j .linux /tmp/BOOTX64.EFI /tmp/kernel
dracut -vv --no-hostonly --force -m 'usrmount bash rootfs-block kernel-modules kernel-network-modules kernel-modules-extra qemu virtfs virtiofs shutdown overlayfs' --add-drivers "crc32c_intel crct10dif_pclmul evdev irqbypass nft_chain_nat sha256_ssse3 vsock xfrm_user xt_MASQUERADE xt_addrtype xt_connmark xt_conntrack xt_mark" /tmp/initrd
ukify build --linux=/tmp/kernel --initrd=/tmp/initrd --cmdline="root=LABEL=root ro rd.driver.pre=sd_mod rd.driver.pre=virtio_scsi rd.debug" --output=/tmp/BOOTX64.NEW.EFI
