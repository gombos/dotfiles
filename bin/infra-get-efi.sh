#!/bin/bash

sudo rm -rf /tmp/efi
cd /tmp

image="0gombi0/homelab:boot"
sudo docker pull $image

container_id=$(sudo docker create $image /)
sudo docker export $container_id | sudo tar xf -

image="0gombi0/homelab:initrd"
sudo docker pull $image

container_id=$(sudo docker create $image /)
sudo docker export $container_id | sudo tar xf -

image="0gombi0/homelab:kernel"
sudo docker pull $image

container_id=$(sudo docker create $image /)
sudo docker export $container_id | sudo tar xf -

sudo chown -R 1000:1000 /tmp/efi
