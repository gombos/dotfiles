#!/bin/bash

FILENAME=linux-flat.vmdk
OUT_DIR=${OUT_DIR:=/tmp/img}
FILE=$OUT_DIR/${FILENAME}
MNT_DIR=${MNT_DIR:=$OUT_DIR/mnt}
MNT=$MNT_DIR/root
MNT_EFI=$MNT_DIR/efi

  mkdir -p $MNT $MNT_EFI
  echo "Installing $RELEASE into $FILE..."

  # 7GB image file to fit comfortable to 8 GB sticks or larger
  IMGSIZE=${IMGSIZE:=7168} # in megabytes

  if [ -f $FILE ]; then
    sudo rm -rf $FILE
  fi

  if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    sudo dd if=/dev/zero of=$FILE bs=1024k seek=${IMGSIZE} count=0
  fi

  # Assigning loopback device to the image file
  DISK=""
  for i in /dev/loop* # or /dev/nbd*
  do
    if sudo losetup $i $FILE
    then
      DISK=$i
      break
    fi
  done
  [ "$DISK" == "" ] && fail "no loop device available"

  echo "Connected $FILE to $DISK"

  # Partition device
  echo "Partitioning $DISK..."

  # format as GPT, GUID Partition Table
  sudo sgdisk -Z $DISK

  sudo sgdisk -n 0:0:+1022M  -t 0:ef00 -c 0:"EFI System Partition"  $DISK
  sudo sgdisk -n 0:0:+6G -t 0:8300 -c 0:"linux"  $DISK

  sudo partprobe $DISK

  sudo mkfs.vfat -F 32 -n EFI ${DISK}p1

  echo "Creating root partition..."
#  sudo mkfs.ext4 -L "linux" -U '76e94507-14c7-4d4a-9154-e70a4c7f8441' ${DISK}p2 || fail "cannot create / ext4"
  sudo mkfs -t btrfs -L "linux" ${DISK}p2 || fail "cannot create /"

  # Mount device
  echo "Mounting partitions..."
  sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"
  sudo mount ${DISK}p2 $MNT || fail "cannot mount"
  sudo btrfs subvolume create $MNT/linux

  cd $MNT/linux
  sudo btrfs subvolume set-default .
  sudo docker pull 0gombi0/homelab:stable
  container_id=$(sudo docker create 0gombi0/homelab:stable /bin/bash)
  sudo docker export $container_id | sudo tar xf -
  sudo docker rm $container_id
  sudo rm -rf dev
  sudo rm -rf run
  # Todo - do we actually need to make these directories ?
  sudo mkdir dev
  sudo mkdir run
  sudo rm -rf etc/hostname
  sudo rm -rf .dockerenv
  # Check before doing it readlink -- "/etc/resolv.conf"
  cd etc
  sudo ln -sf ../run/systemd/resolve/stub-resolv.conf resolv.conf
  # Make it read-only
  sudo btrfs property set -ts $MNT/linux ro true
  sync
  cd /
  sudo umount $MNT

  sudo rm -rf /tmp/efi
  mkdir /tmp/efi
  cd /tmp/efi
  sudo docker pull 0gombi0/homelab-base:efi
  container_id=$(sudo docker create 0gombi0/homelab-base:efi /bin/bash)
  sudo docker export $container_id | sudo tar xf -
  sudo rsync -rv /tmp/efi/efi/ $MNT_EFI
  sudo git clone https://github.com/gombos/dotfiles $MNT_EFI/dotfiles

  # https://wiki.archlinux.org/title/Syslinux
  sudo sgdisk $DISK --attributes=1:set:2
  sudo dd bs=440 count=1 conv=notrunc if=$MNT_EFI/syslinux/gptmbr.bin of=$DISK
  sudo extlinux --install $MNT_EFI/syslinux/
  sync
  cd /

  # directories that are not needed for vm
  sudo rm -rf $MNT_EFI/syslinux $MNT_EFI/EFI/ubuntu $MNT_EFI/grub $MNT_EFI/tce $MNT_EFI/ipxe
  sudo umount $MNT_EFI

  sudo losetup -d /dev/loop* 2>/dev/null
