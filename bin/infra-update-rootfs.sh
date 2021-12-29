#!/bin/bash

DIR=$MNTDIR/linux/tmproot

rw $MNTDIR/linux
sudo btrfs subvolume create $DIR
sudo chmod g+w $DIR

infra-get-rootfs.sh $DIR

cd $DIR
version=$(cat var/integrity/id)
cd ..
sudo mv tmproot linux-$version

# Todo - Dedup
#sudo rmlint --types="duplicates" --config=sh:handler=clone $DIR
#sudo ./rmlint.sh -r

# Make it read-only
sudo btrfs property set -ts linux-$version ro true
sudo btrfs subvolume set-default linux-$version
