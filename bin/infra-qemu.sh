qemu-system-x86_64 -boot d -cdrom  kucko.iso -m 5120 -machine type=q35,accel=hvf -smp 2 -usb -device usb-tablet -display default,show-cursor=on
