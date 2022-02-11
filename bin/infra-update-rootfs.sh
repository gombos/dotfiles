#!/bin/bash

DIR=$MNTDIR/shared/tmproot

rw $MNTDIR/shared
sudo rm -rf $DIR
sudo btrfs subvolume create $DIR
sudo chmod g+w $DIR

infra-get-rootfs.sh $DIR

cd $DIR
version=$(date | md5sum | head -c 4)
echo $version
cd ..
sudo mv $DIR $MNTDIR/shared/linux-$version

# Todo - Dedup
#sudo rmlint --types="duplicates" --config=sh:handler=clone $DIR
#sudo ./rmlint.sh -r

# Make it read-only
sudo btrfs property set -ts linux-$version ro true
sudo btrfs subvolume set-default linux-$version

ro $MNTDIR/shared
