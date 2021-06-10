# Run this on mac

$DISK=$1
[[ ! -z "$DISK" ]] && $DISK=disk2

diskutil unmountDisk $DISK

gpt destroy $DISK

gpt create -f $DISK

# EFI (fat32) - 200 MB
gpt add -i 1 -b        40 -s   2095064 -t C12A7328-F81F-11D2-BA4B-00A0C93EC93B $DISK

# GRUB BIOS
gpt add -i 2 -b   2095104 -s      2048 -t 21686148-6449-6E6F-744E-656564454649 $DISK

# Linux (btrfs)
gpt add -i 3 -b   2097152 -s  50331648 -t 0FC63DAF-8483-4772-8E79-3D69D8477DE4 $DISK

# MacOS (afps)
gpt add -i 4 -b  52428800 -s  66406248 -t 7C3457EF-0000-11AA-AA11-00306543ECAC $DISK

# live (hfs) - Windows VM
gpt add -i 5 -b  118835048 -t 48465300-0000-11AA-AA11-00306543ECAC $DISK

diskutil umountDisk $DISK
