#!/bin/sh

ID_SERIAL="$(sudo udevadm info --query=property $1 | grep "ID_SERIAL=" -m1 | cut -d\= -f2 | sed -e 's/ /_/g')"
ID_PART_TABLE_UUID=$(sudo udevadm info --query=property $1 | grep "ID_PART_TABLE_UUID=" -m1 | cut -d\= -f2)
ID_PART_TABLE_TYPE=$(sudo udevadm info --query=property $1 | grep "ID_PART_TABLE_TYPE=" -m1 | cut -d\= -f2)

echo ${ID_SERIAL}

if [ "$ID_PART_TABLE_TYPE" = "gpt" ]; then
  sudo sgdisk --backup=backup.sgdisk_${ID_SERIAL}_${ID_PART_TABLE_UUID} $1 # for GPT
fi

if [ "$ID_PART_TABLE_TYPE" = "dos" ]; then
  sudo sfdisk -d $1 > backup.sfdisk_${ID_SERIAL}_${ID_PART_TABLE_UUID} # for MBR
fi

sudo sgdisk -p $1 > ${ID_SERIAL}_${ID_PART_TABLE_UUID}
