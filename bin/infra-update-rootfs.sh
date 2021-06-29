#!/bin/bash

mnt linux_bestia

DIR=$MNTDIR/linux_bestia/tmp
btrfs subvolume create $DIR

infra-get-rootfs $DIR

cd $DIR
version=$(cat var/integrity/id)
echo $version
cd ..
sudo mv $DIR linux-$version

# Todo - Dedup
#sudo rmlint --types="duplicates" --config=sh:handler=clone $DIR
#sudo ./rmlint.sh -r

chmod o+w linux-$version

# Make it read-only
sudo btrfs property set -ts linux-$version ro true
sudo btrfs subvolume set-default linux-$version

# Print size
sudo du -hs linux-$version
