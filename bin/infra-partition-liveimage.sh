# Run this on mac

$DISK=$1
[[ ! -z "$DISK" ]] && $DISK=disk2

diskutil unmountDisk $DISK

gpt destroy $DISK

gpt create -f $DISK

# EFI (fat32)
gpt add -i 1 -b        40 -s    409600 -t C12A7328-F81F-11D2-BA4B-00A0C93EC93B $DISK

# GRUB BIOS
gpt add -i 2 -b   2095104 -s 117872752 -t 7C3457EF-0000-11AA-AA11-00306543ECAC $DISK

# Windows (ntfs)
gpt add -i 3 -b   2097152 -s 116922368 -t EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 $DISK

# MS Reserved
gpt add -i 4 -b  67076096 -s     32768 -t E3C9E316-0B5C-4DB8-817D-F92DF00215AE $DISK

# MacOS (afps)
gpt add -i 5 -b  67108864 -s 118872752 -t 7C3457EF-0000-11AA-AA11-00306543ECAC $DISK

# Linux (btrfs)
gpt add -i 6 -b 134217728 -s  50331648 -t 48465300-0000-11AA-AA11-00306543ECAC $DISK

# live (hfs) - Windows VM
