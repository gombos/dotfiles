if [ -f "$1" ]; then
  ISO=$1
else
  ISO="/go/efi/linux.iso"
fi

mkdir /tmp/mnt
sudo umount /tmp/mnt 2>/dev/null
sudo mount $ISO /tmp/mnt

#qemu-system-x86_64 -nodefaults -snapshot -cpu host -boot d -cdrom  ~/linux.iso -m 4G -machine type=q35,accel=hvf -smp 2 -net user -net nic -vga virtio -usb -device usb-tablet  -display default,show-cursor=on -device ich9-intel-hda,addr=1f.1 -audiodev pa,id=snd0  -device hda-output,audiodev=snd0

# simplest to boot, but does not work
#qemu-system-x86_64 -nographic -cdrom /go/efi/isos/linux.iso -m 512 -append "console=ttyS0"

# simplest boot without initrd
#qemu-system-x86_64 -m 512 -snapshot -nographic -kernel /mnt/kernel/vmlinuz -drive file=/mnt/Live/squashfs.img,if=ide -append "console=ttyS0 root=/dev/sda"

# try to make networking work, but modules can not be loaded
#qemu-system-x86_64 -m 512 -snapshot -nographic -kernel /mnt/kernel/vmlinuz -drive file=/mnt/Live/squashfs.img,if=ide,format=raw -netdev user,id=net0 -device e1000,netdev=net0  -append "console=ttyS0 root=/dev/sda rw net.ifnames=0"

# with initrd
sudo cat /tmp/mnt/kernel/initrd*img > /tmp/initrd && sudo qemu-system-x86_64 -m 512 -nographic --enable-kvm -kernel /tmp/mnt/kernel/vmlinuz -initrd /tmp/initrd --cdrom $ISO -append "console=ttyS0 root=live:CDLABEL=ISO"

# todo
#switch to UEFI boot with full iso as test case
#qemu-system-x86_64 -m 1024 -nographic --enable-kvm --cdrom /go/efi/linux.iso -global driver=cfi.pflash01,property=secure,value=on -drive if=pflash,format=raw,unit=0,file="/usr/share/OVMF/OVMF_CODE.fd",readonly=on

sudo umount /tmp/mnt 2>/dev/null

# -nodefaults -cpu host

# qemu-system-x86_64 -m 1024  --enable-kvm --cdrom linux-core.iso  -global driver=cfi.pflash01,property=secure,value=on -drive if=pflash,format=raw,unit=0,file="/usr/share/OVMF/OVMF_CODE.fd",readonly=on -boot d -nographic -serial mon:stdio
