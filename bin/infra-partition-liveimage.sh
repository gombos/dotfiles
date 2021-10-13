# Run this on mac

$DISK=$1
[[ ! -z "$DISK" ]] && $DISK=disk2

diskutil unmountDisk $DISK

gpt destroy $DISK

gpt create -f $DISK

# TODO - test

# EFI (fat32) - 1 GB
gpt add -i 1 -b        40 -s   2095064 -t C12A7328-F81F-11D2-BA4B-00A0C93EC93B $DISK

# NTFS - ISOs
# TODO - check size
gpt add -i 2 -s 25165824 -t EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 $DISK

# 2095103

## Linux (btrfs)
#gpt add -i 2 -s 25165824 -t 0FC63DAF-8483-4772-8E79-3D69D8477DE4 $DISK

#  50331648 -t 0FC63DAF-8483-4772-8E79-3D69D8477DE4 $DISK
## -b   2095104 -s  50331648 -t 0FC63DAF-8483-4772-8E79-3D69D8477DE4 $DISK
#
## MacOS (afps)
#gpt add -i 3 -b  52426752 -s  66406248 -t 7C3457EF-0000-11AA-AA11-00306543ECAC $DISK

# HFS - Windows VM
gpt add -i 3 -b  118833000 -t 48465300-0000-11AA-AA11-00306543ECAC $DISK

#gpt add -t 48465300-0000-11AA-AA11-00306543ECAC -s 207180687 $DISK

diskutil umountDisk $DISK

diskutil eraseVolume JHFS+ home_live ${DISK}s3
diskutil disableJournal ${DISK}s3

#gpt add -t 48465300-0000-11AA-AA11-00306543ECAC -s 156849039 /dev/disk3
#gpt add -i 3 -s 50331648 -t linux /dev/disk3

#MS data
# EBD0A0A2-B9E5-4433-87C0-68B6B72699C7
#https://en.wikipedia.org/wiki/GUID_Partition_Table
# diskutil list
# gpt -r show

