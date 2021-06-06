#!/bin/bash

container_id=$(sudo docker create 0gombi0/homelab:initrd)

sudo docker cp $container_id:/efi/initrd-nfs.img /go/efi/kernel/
sudo docker cp $container_id:/efi/initrd.img /go/efi/kernel/

sudo docker rm $container_id

