#!/bin/bash

image="0gombi0/homelab:raw"
sudo docker pull $image

sudo rm -rf /tmp/img
mkdir /tmp/img
cd /tmp/img

container_id=$(sudo docker create $image /)
sudo docker export $container_id | sudo tar xf -

sudo chown -R 1000:1000 /tmp/img

sudo mv /tmp/img/tmp/linux.img /tmp
sudo rm -rf /tmp/img
