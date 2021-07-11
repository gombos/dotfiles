#!/bin/bash

#img
#raw
#vdi
#vpc
#vmdk

OUT=$2

sudo umount $OUT 2>/dev/null

rm -rf $OUT
mkdir -p $OUT

IN=$1

# Check if input is a directory
if [[ -d $IN ]]; then
  exit
fi

IN_EXT="${IN#*.}"

#if [ "$IN_EXT" == "tar.xz" ] || [ "$IN_EXT" == "tar.gz" ] || [ "$IN_EXT" == "tgz" ] || [ "$IN_EXT" == "txz" ] || [ "$IN_EXT" == "tar" ]; then
#  archivemount $IN $OUT
#fi

if [ "$IN_EXT" == "img" ]; then
  DEV=$(sudo losetup --show -f -P $IN)
  sudo mount ${DEV}p1 $OUT
fi
