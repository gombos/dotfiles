if [ -f "$1" ]; then
  ISO=$1
else
  #ISO="/go/efi/linux.iso"
  ISO=~/linux*.iso
fi

#mkdir /tmp/mnt
#sudo umount /tmp/mnt 2>/dev/null
#sudo mount $ISO /tmp/mnt

#qemu-system-x86_64 -nodefaults -snapshot -cpu host -boot d -cdrom  ~/linux.iso -m 4G -machine type=q35,accel=hvf -smp 2 -net user -net nic -vga virtio -usb -device usb-tablet  -display default,show-cursor=on -device ich9-intel-hda,addr=1f.1 -audiodev pa,id=snd0  -device hda-output,audiodev=snd0

# simplest to boot, but does not work
#qemu-system-x86_64 -nographic -cdrom /go/efi/isos/linux.iso -m 512 -append "console=ttyS0"

# simplest boot without initrd
#qemu-system-x86_64 -m 512 -snapshot -nographic -kernel /mnt/kernel/vmlinuz -drive file=/mnt/Live/squashfs.img,if=ide -append "console=ttyS0 root=/dev/sda"

# try to make networking work, but modules can not be loaded
#qemu-system-x86_64 -m 512 -snapshot -nographic -kernel /mnt/kernel/vmlinuz -drive file=/mnt/Live/squashfs.img,if=ide,format=raw -netdev user,id=net0 -device e1000,netdev=net0  -append "console=ttyS0 root=/dev/sda rw net.ifnames=0"

# with initrd
#sudo cat /tmp/mnt/kernel/initrd*img > /tmp/initrd && sudo qemu-system-x86_64 -m 512 -nographic --enable-kvm -kernel /tmp/mnt/kernel/vmlinuz -initrd /tmp/initrd --cdrom $ISO -append "console=ttyS0 root=live:CDLABEL=ISO"

# todo
#switch to UEFI boot with full iso as test case
f=$(ls /opt/homebrew/Cellar/qemu/*/share/qemu/edk2-x86_64-code.fd)

#qemu-system-aarch64 --cdrom $ISO -cpu cortex-a57 -M virt,highmem=off -monitor stdio -vga none

#!/bin/sh
#qemu-system-aarch64 \
#    -accel hvf \
#    -m 2048 \
#    -cpu cortex-a57 -M virt,highmem=off  \
#    -drive file=/usr/local/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on \
#    -drive file=ovmf_vars.fd,if=pflash,format=raw \
#    -serial telnet::4444,server,nowait \
#    -drive if=none,file=disk.qcow2,format=qcow2,id=hd0 \
#    -device virtio-blk-device,drive=hd0,serial="dummyserial" \
#    -device virtio-net-device,netdev=net0 \
#    -netdev user,id=net0 \
#    -vga none -device ramfb \
#    -cdrom ubuntu-20.04.2-live-server-arm64.iso \
#    -device usb-ehci -device usb-kbd -device usb-mouse -usb \
#    -monitor stdio



qemu-system-x86_64 -m 1024 -nographic -drive file=fat:rw:~/.dotfiles/boot,format=vvfat,label=CONFIG --cdrom $ISO -global driver=cfi.pflash01,property=secure,value=on  -drive if=pflash,format=raw,unit=0,file="$f"
#-drive if=pflash,format=raw,unit=0,file="/opt/homebrew/Cellar/qemu/8.2.0/share/qemu/edk2-x86_64-code.fd",readonly=on -smbios type=11,value=io.systemd.stub.kernel-cmdline-extra="$1"

# -fw_cfg name=opt/io.dracut/cmdline,string="root=live:/dev/disk/by-label/ISO $1" -smbios type=11,value=io.dracut:cmdline=ro

#sudo umount /tmp/mnt 2>/dev/null

# -nodefaults -cpu host

# qemu-system-x86_64 -m 1024  --enable-kvm --cdrom linux-core.iso  -global driver=cfi.pflash01,property=secure,value=on -drive if=pflash,format=raw,unit=0,file="/usr/share/OVMF/OVMF_CODE.fd",readonly=on -boot d -nographic -serial mon:stdio
