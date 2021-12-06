#!/bin/bash

if [ -z "$1" ]; then
  image="0gombi0/homelab-baremetal:squashfs"
  sudo docker pull $image
else
  image="$1"
fi

sudo rm -rf /tmp/squashfs
mkdir /tmp/squashfs
cd /tmp/squashfs

container_id=$(sudo docker create $image /)
sudo docker export $container_id | sudo tar xf -

sudo chown -R 1000:1000 /tmp/squashfs
