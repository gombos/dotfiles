#!/bin/bash

container_id=$(sudo docker create -ti -v /tmp:/tmp 0gombi0/homelab:efi bash)
sudo docker start $container_id

sudo docker exec $container_id  rsync -av /efi /tmp

sudo docker rm -f $container_id

