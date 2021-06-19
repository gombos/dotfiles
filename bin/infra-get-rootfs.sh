#!/bin/bash

# arg1 = dir, arg2 = container

# todo - discover if podman is available and use podman instead of docker if available
# todo - does this really needs sudo ?

mnt linux
DIR=$MNTDIR/linux/linux-dev

# it is only possible to “flatten” a Docker container, not an image.
#container_id=$(sudo docker run -dit 0gombi0/homelab:base /bin/bash)
#sudo docker stop $container_id

#docker builder prune -af

# todo - does this invalidates the docker cache ?
docker pull 0gombi0/homelab:desktop

container_id=$(sudo docker create 0gombi0/homelab:desktop)

sudo btrfs property set -ts $DIR ro false
sudo btrfs subvolume delete $DIR 2>/dev/null
sudo btrfs subvolume create $DIR

cd $DIR
sudo docker export $container_id  | sudo tar xf -
sudo docker rm $container_id

sudo rm -rf dev
sudo rm -rf run

# Todo - do we actually need to make these directories ?
sudo mkdir dev
sudo mkdir run

sudo rm -rf etc/hostname
sudo rm -rf .dockerenv

# Check before doing it readlink -- "/etc/resolv.conf"
cd $DIR/etc
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf resolv.conf
cd $DIR

# Todo - Dedup
#sudo rmlint --types="duplicates" --config=sh:handler=clone $DIR
#sudo ./rmlint.sh -r

# Make it read-only
sudo btrfs property set -ts $DIR ro true

# Print size
sudo du -hs $DIR
