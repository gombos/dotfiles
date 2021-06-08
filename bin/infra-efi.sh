#!/bin/bash

sudo docker run -v /tmp:/tmp 0gombi0/homelab:efi rsync -av /efi /tmp

#sudo docker rm $container_id

