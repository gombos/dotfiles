#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash cpio dracut --pure

dracut -vv --no-hostonly --force -m 'bash rootfs-block kernel-modules qemu virtfs virtiofs shutdown overlayfs' /tmp/initrd


#nix-shell --packages dracut cpio --run sudo env PATH="$PATH" dracut -v --no-hostonly --no-hostonly-cmdline -m "bash rootfs-block kernel-modules qemu virtfs virtiofs shutdown" initrd

#sudo env PATH="$PATH" dracut -v --no-hostonly --no-hostonly-cmdline -m "bash rootfs-block kernel-modules qemu virtfs virtiofs shutdown" initrd

#/usr/lib/systemd/ukify build --linux=vmlinuz --initrd=initrd --cmdline="root=LABEL=root ro rd.driver.pre=sd_mod rd.driver.pre=virtio_scsi"
