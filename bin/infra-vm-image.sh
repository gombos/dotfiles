#!/bin/bash

FILE=rootfs.raw
OUT_DIR=${OUT_DIR:=out}
MNT_DIR=${MNT_DIR:=$OUT_DIR/${FNAME}}

create_img_file() {
  echo "Installing $RELEASE into $FILE..."

  # 6GB image file
  IMGSIZE=${IMGSIZE:=6144} # in megabytes

  if [ -f $FILE ]; then
    sudo rm -rf $FILE
  fi

  if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    sudo dd if=/dev/zero of=$FILE bs=1024k seek=${IMGSIZE} count=0
  fi

  mkdir -p $MNT_DIR

  # Assigning loopback device to the image file
  DISK=""
  for i in /dev/loop* # or /dev/nbd*
  do
    if sudo losetup $i $FILE # or qemu-nbd -c $i $FILE
    then
      DISK=$i
      break
    fi
  done
  [ "$DISK" == "" ] && fail "no loop device available"

  echo "Connected $FILE to $DISK"

  # Partition device
  echo "Partitioning $DISK..."

  printf "label: dos\n;\n" | sudo sfdisk $DISK -q || fail "cannot partition $FILE"
  sudo partprobe $DISK

  echo "Creating root partition..."
  sudo mkfs.ext4 -L rootfs -U '76e94507-14c7-4d4a-9154-e70a4c7f8441' ${DISK}p1 || fail "cannot create / ext4"

  # Mount device
  echo "Mounting root partition..."
  sudo mount ${DISK}p1 $MNT_DIR || fail "cannot mount /"
}

umount_image() {
  sudo umount $MNT_DIR
  sudo losetup -d /dev/loop* 2>/dev/null
}

if [ "$FILE" != "" ]; then
  create_img_file
  cd $MNT_DIR

  sudo docker pull 0gombi0/homelab:base
  container_id=$(sudo docker create 0gombi0/homelab:base)
  sudo docker export $container_id  | sudo tar xf -
  sudo docker rm $container_id

  cd -
  umount_image
fi
