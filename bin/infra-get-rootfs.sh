#!/bin/bash

# arg1 = directory where rootfs will be exported
# arg2 = container to export

# todo - discover if podman is available and use podman instead of docker if available
# todo - does this really needs sudo ?

DIR=$1

[ -z "$DIR" ] && exit

if [ -z "$2" ]; then
  image="0gombi0/homelab-baremetal:rootfs"
else
  image="$2"
fi

docker pull $image
container_id=$(sudo docker create $image /)

cd $DIR
docker export $container_id  | sudo tar xf -
docker rm $container_id

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

