#!/bin/bash

sudo rm -rf /tmp/efi
mkdir /tmp/efi
cd /tmp/efi
sudo docker pull 0gombi0/homelab:efi
container_id=$(sudo docker create 0gombi0/homelab:efi /bin/bash)
sudo docker export $container_id | sudo tar xf -
sudo rsync -r /tmp/efi/efi/ $MNT_EFI

sudo chown -R 1000:1000 /tmp/efi
