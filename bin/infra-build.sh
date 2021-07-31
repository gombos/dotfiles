#!/bin/sh

docker build ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-base --tag 0gombi0/homelab:base
docker build ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-efi --tag 0gombi0/homelab:efi
docker build ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-desktop --tag 0gombi0/homelab:desktop

infra-vm-image.sh
