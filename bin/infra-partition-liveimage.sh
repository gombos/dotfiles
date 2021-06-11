# Run this on mac

$DISK=$1
[[ ! -z "$DISK" ]] && $DISK=disk2

diskutil unmountDisk $DISK

gpt destroy $DISK

gpt create -f $DISK

# EFI (fat32) - 200 MB
gpt add -i 1 -b        40 -s   2095064 -t C12A7328-F81F-11D2-BA4B-00A0C93EC93B $DISK

# Linux (btrfs)
gpt add -i 2 -b   2095104 -s  50331648 -t 0FC63DAF-8483-4772-8E79-3D69D8477DE4 $DISK

# MacOS (afps)
gpt add -i 3 -b  52426752 -s  66406248 -t 7C3457EF-0000-11AA-AA11-00306543ECAC $DISK

# live (hfs) - Windows VM
gpt add -i 4 -b  118833000 -t 48465300-0000-11AA-AA11-00306543ECAC $DISK

diskutil umountDisk $DISK

MS data
# EBD0A0A2-B9E5-4433-87C0-68B6B72699C7
https://en.wikipedia.org/wiki/GUID_Partition_Table
