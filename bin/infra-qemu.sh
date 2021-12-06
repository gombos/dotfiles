qemu-system-x86_64 -nodefaults -snapshot -cpu host -boot d -cdrom  ~/linux.iso -m 4G -machine type=q35,accel=hvf -smp 2 -display default,show-cursor=on -device VGA -net user -net nic
