#!/bin/sh

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/build-infra.log 2>&1

RELEASE=focal
sudo rm -rf /tmp/minbase
sudo LANG=C  debootstrap --variant=minbase --components=main,universe $RELEASE /tmp/minbase

sudo tar -c /tmp/minbase | docker import - 0gombi0/homelab:minbase
docker push 0gombi0/homelab:minbase

docker build -t 0gombi0/homelab:base    ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-base
docker push 0gombi0/homelab:base

docker build -t 0gombi0/homelab:desktop ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-desktop
docker push 0gombi0/homelab:desktop

docker build -t 0gombi0/homelab:efi     ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-efi
docker push 0gombi0/homelab:efi

infra-vm-image.sh

sudo tar -c /tmp/linux-flat.vmdk | docker import - 0gombi0/homelab:raw
docker push 0gombi0/homelab:raw
