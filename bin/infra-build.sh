#!/bin/sh

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/build-infra.log 2>&1

RELEASE=focal

if ! [ -z "$1" ]; then
  TARGET="$1"
else
  TARGET="minbase base desktop efi laptop"
fi

if echo $TARGET | grep -w -q minbase; then
  sudo rm -rf /tmp/minbase
  sudo LANG=C debootstrap --variant=minbase --components=main,universe $RELEASE /tmp/minbase
  sudo tar -c /tmp/minbase | docker import - 0gombi0/homelab:minbase
  docker push 0gombi0/homelab:minbase
  sudo rm -rf /tmp/minbase
else
  docker pull 0gombi0/homelab:minbase
fi

if echo $TARGET | grep -w -q base; then
  docker build -t 0gombi0/homelab:base    ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-base
  docker push 0gombi0/homelab:base
else
  docker pull 0gombi0/homelab:base
fi

if echo $TARGET | grep -w -q desktop; then
  docker build -t 0gombi0/homelab:desktop ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-desktop
  docker push 0gombi0/homelab:desktop
else
  docker pull 0gombi0/homelab:desktop
fi

if echo $TARGET | grep -w -q efi; then
  docker build -t 0gombi0/homelab:efi     ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-efi
  docker push 0gombi0/homelab:efi
else
  docker pull 0gombi0/homelab:efi
fi

if echo $TARGET | grep -w -q laptop; then
  docker build -t 0gombi0/homelab:laptop     ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-laptop
  docker push 0gombi0/homelab:laptop
else
  docker pull 0gombi0/homelab:laptop
fi

#infra-image.sh

#sudo tar -c /tmp/linux.img | docker import - 0gombi0/homelab:raw
#docker push 0gombi0/homelab:raw
