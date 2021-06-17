#!/bin/bash

FILE=rootfs.raw
OUT_DIR=${OUT_DIR:=out}
MNT_DIR=${MNT_DIR:=$OUT_DIR/${FNAME}}

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

  mkdir -p $MNT_DIR

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

  sudo sgdisk -n 0:0:+200M  -t 0:ef00 -c 0:"EFI System Partition"  $DISK
  sudo sgdisk -n 0:0:+6000M -t 0:8300 -c 0:"linux"  $DISK

  sudo partprobe $DISK

  sudo mkfs.vfat ${DISK}p1

  echo "Creating root partition..."
  sudo mkfs.ext4 -L "linux" -U '76e94507-14c7-4d4a-9154-e70a4c7f8441' ${DISK}p2 || fail "cannot create / ext4"

  # Mount device
  echo "Mounting root partition..."
  sudo mount ${DISK}p2 $MNT_DIR || fail "cannot mount /"

  cd $MNT_DIR
  sudo docker pull 0gombi0/homelab-base
  container_id=$(sudo docker create 0gombi0/homelab-base)
  sudo docker export $container_id  | sudo tar xf -
  sudo docker rm $container_id

  cd -

  cp $MNT_DIR/usr/lib/systemd/boot/efi/systemd-bootx64.efi /tmp/
  sudo cp $MNT_DIR/boot/vmlinuz /tmp/
  sudo umount $MNT_DIR

  sudo mount ${DISK}p1 $MNT_DIR || fail "cannot mount /"

  sudo mkdir -p $MNT_DIR/EFI/BOOT/
  sudo mkdir -p $MNT_DIR/kernel/

  sudo cp /tmp/systemd-bootx64.efi   $MNT_DIR/EFI/BOOT/BOOTX64.EFI
  sudo cp /tmp/vmlinuz   $MNT_DIR/kernel/
  sudo cp /go/efi_bestia/kernel/initrd.img  $MNT_DIR/kernel/

  sudo mkdir -p $MNT_DIR/loader/entries

cat << 'EOF' | sudo tee -a $MNT_DIR/loader/entries/linux.conf
title   linux
linux   /kernel/vmlinuz
initrd  /kernel/initrd.img
options root=/dev/sda2 rw
EOF

cat << 'EOF' | sudo tee -a $MNT_DIR/loader/loader.conf
timeout 0
default linux
EOF

  sudo umount $MNT_DIR
  sudo losetup -d /dev/loop* 2>/dev/null

  qemu-img convert -O vmdk rootfs.raw vmdkname.vmdk
