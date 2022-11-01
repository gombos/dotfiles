#!/bin/bash

image="0gombi0/homelab:efi"
sudo docker pull $image

sudo rm -rf /tmp/efi
cd /tmp

container_id=$(sudo docker create $image /)
sudo docker export $container_id | sudo tar xf -

sudo chown -R 1000:1000 /tmp/efi
