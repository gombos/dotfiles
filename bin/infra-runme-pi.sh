
if ! [ -f $1 ]; then
  if ! [ -f tryrun.img ]; then
    cp base-stretch-armhf.img tryrun.img
  fi
else
  ln -sf $1 tryrun.img
fi

if ! [ -f kernel-qemu-4.14.50-stretch ]; then
  wget https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/kernel-qemu-4.14.79-stretch
fi

if ! [ -f versatile-pb.dtb ]; then
  wget https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/versatile-pb.dtb
fi

qemu-system-arm -kernel kernel-qemu-4.14.79-stretch -cpu arm1176 -m 256 -M versatilepb -dtb versatile-pb.dtb -serial stdio -no-reboot -hda tryrun.img -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" -net user,hostfwd=tcp::5022-:22 -net nic

#qemu-system-arm -kernel kernel-qemu-4.14.50-stretch -cpu arm1176 -m 256 -M versatilepb -dtb versatile-pb.dtb -serial mon:stdio -no-reboot -hda tryrun.img -append "root=/dev/sda2 panic=1 rootfstype=ext4 console=ttyS0 console=ttyAMA0 console=tty0 rw" -net user,hostfwd=tcp::5022-:22 -net nic -nographic

# -append 'console=ttyS0' binary.img

#-nographic
#init=/bin/bash"
#-drive format=raw,file=tryrun.img
#-net user,hostfwd=tcp::5022-:22 -net nic
#-net user,hostfwd=tcp::5022-:22,vlan=0 -net nic,vlan=0
