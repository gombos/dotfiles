#!/bin/bash

if [ -z "$1" ]; then
  image="0gombi0/homelab:efi"
  sudo docker pull $image
else
  image="$1"
fi

sudo rm -rf /tmp/efi
mkdir /tmp/efi
cd /tmp/efi

container_id=$(sudo docker create $image /bin/bash)
sudo docker export $container_id | sudo tar xf -

sudo chown -R 1000:1000 /tmp/efi
