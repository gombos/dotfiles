#!/bin/bash

# arg1 = dir, arg2 = container

# todo - discover if podman is available and use podman instead of docker if available
# todo - does this really needs sudo ?

DIR=$1

docker pull 0gombi0/homelab:desktop
container_id=$(sudo docker create 0gombi0/homelab:desktop)

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

