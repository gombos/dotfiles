#!/bin/bash

FILE=rootfs.raw
OUT_DIR=${OUT_DIR:=/tmp/img}
MNT_DIR=${MNT_DIR:=$OUT_DIR/${FNAME}}
MNT=$MNT_DIR/root
MNT_EFI=$MNT_DIR/efi

  echo "Installing $RELEASE into $FILE..."

  # 6GB image file
  IMGSIZE=${IMGSIZE:=7144} # in megabytes

  if [ -f $FILE ]; then
    sudo rm -rf $FILE
  fi

  if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    sudo dd if=/dev/zero of=$FILE bs=1024k seek=${IMGSIZE} count=0
  fi

  mkdir -p $MNT $MNT_EFI

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

  # format /dev/sdb as GPT, GUID Partition Table
  sudo sgdisk -Z $DISK

  sudo sgdisk -n 0:0:+1G  -t 0:ef00 -c 0:"EFI System Partition"  $DISK
  sudo sgdisk -n 0:0:+5G -t 0:8300 -c 0:"linux"  $DISK

  sudo partprobe $DISK

  sudo mkfs.vfat -F 32 -n EFI ${DISK}p1

  echo "Creating root partition..."
  sudo mkfs.ext4 -L "linux" -U '76e94507-14c7-4d4a-9154-e70a4c7f8441' ${DISK}p2 || fail "cannot create / ext4"

  # Mount device
  echo "Mounting partitions..."
  sudo mount ${DISK}p1 $MNT_EFI || fail "cannot mount"
  sudo mount ${DISK}p2 $MNT || fail "cannot mount"

  cd $MNT
  sudo docker pull 0gombi0/homelab-base:latest
  container_id=$(sudo docker create 0gombi0/homelab-base:latest /bin/bash)
  sudo docker export $container_id  | sudo tar xf -
  sudo docker rm $container_id
  sync
#  sudo umount $MNT
  cd -

  sudo rm -rf /tmp/efi
  mkdir /tmp/efi
  cd /tmp/efi
  sudo docker pull 0gombi0/homelab-base:efi
  container_id=$(sudo docker create 0gombi0/homelab-base:efi /bin/bash)
  sudo docker export $container_id  | sudo tar xf -
  sudo rsync -av /tmp/efi/efi/ $MNT_EFI
  sync
#  sudo umount $MNT_EFI
  cd -

  sudo losetup -d /dev/loop* 2>/dev/null
  qemu-img convert -O vmdk rootfs.raw vmdkname.vmdk
