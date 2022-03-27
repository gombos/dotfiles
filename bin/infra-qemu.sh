if [ -f "$1" ]; then
  ISO=$1
else
  ISO="/go/efi/isos/linux.iso"
fi

mkdir /tmp/mnt
sudo umount /tmp/mnt 2>/dev/null
sudo mount $ISO /tmp/mnt

#qemu-system-x86_64 -nodefaults -snapshot -cpu host -boot d -cdrom  ~/linux.iso -m 4G -machine type=q35,accel=hvf -smp 2 -net user -net nic -vga virtio -usb -device usb-tablet  -display default,show-cursor=on -device ich9-intel-hda,addr=1f.1 -audiodev pa,id=snd0  -device hda-output,audiodev=snd0

# simplest to boot, but does not work
#qemu-system-x86_64 -cdrom /go/efi/isos/linux.iso -m 512

# simplest boot without initrd
#qemu-system-x86_64 -m 512 -snapshot -nographic -kernel /mnt/kernel/vmlinuz -drive file=/mnt/Live/squashfs.img,if=ide -append "console=ttyS0 root=/dev/sda"

# try to make networking work, but modules can not be loaded
#qemu-system-x86_64 -m 512 -snapshot -nographic -kernel /mnt/kernel/vmlinuz -drive file=/mnt/Live/squashfs.img,if=ide,format=raw -netdev user,id=net0 -device e1000,netdev=net0  -append "console=ttyS0 root=/dev/sda rw net.ifnames=0"

# with initrd
cat /tmp/mnt/kernel/initrd*img > /tmp/initrd && qemu-system-x86_64 -m 1024 -snapshot -nographic --enable-kvm -kernel /tmp/mnt/kernel/vmlinuz -initrd /tmp/initrd --cdrom $ISO \
-append "console=ttyS0 systemd.mask=docker root=live:CDLABEL=ISO rd.break"

# -nodefaults -cpu host
