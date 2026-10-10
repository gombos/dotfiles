#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash cpio dracut systemdUkify

# handle /, /usr, /usr/lib/modules all in different mount points

# mount /usr/lib/modules from systemd but very early on - this is in /etc/fstab

objcopy -O binary -j .linux /tmp/BOOTX64.EFI /tmp/kernel
dracut --no-hostonly --force --modules 'usrmount kernel-modules-export bash rootfs-block kernel-modules qemu qemu-net virtfs virtiofs shutdown overlayfs'  --drivers 'virtio-balloon' /tmp/initrd
ukify build --linux=/tmp/kernel --initrd=/tmp/initrd --cmdline="root=LABEL=root ro rd.driver.pre=sd_mod rd.driver.pre=virtio_scsi rd.driver.pre=virtio_net rd.driver.pre=autofs4 rd.driver.pre=virtio-balloon quiet" --output=/tmp/BOOTX64.NEW.EFI

# make sure rootfs and /usr drives are visible by the kernel
# rd.driver.pre=sd_mod rd.driver.pre=virtio_scsi

# load networking early, so that it is available right after switch_root
# rd.driver.pre=virtio_net

# load autofs4 early so that it is available for systemd right after switch_root
# rd.driver.pre=autofs4

# overlayfs
