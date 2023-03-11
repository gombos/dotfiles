#!/bin/sh

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/build-infra.log 2>&1

. infra-env.sh

# extra targets
# container upload

if ! [ -z "$1" ]; then
  TARGET="$1"
else
  TARGET="iso"
fi

if echo $TARGET | grep -w -q kernel; then
  docker build -t ghcr.io/gombos/kernel     ~/.dotfiles/ -f ~/.dotfiles/containers/Dockerfile-kernel
  docker push     ghcr.io/gombos/kernel
fi

if echo $TARGET | grep -w -q extra; then
  docker build -t ghcr.io/gombos/rootfs-extra     ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-homelab-extra
  docker push     ghcr.io/gombos/rootfs-extra
fi

if echo $TARGET | grep -w -q config; then
  DOCKER_BUILDKIT=1 docker build -t ghcr.io/gombos/rootfs            ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-homelab-config
  docker push     ghcr.io/gombos/rootfs
fi

if echo $TARGET | grep -w -q usrlocal; then
  DOCKER_BUILDKIT=1 docker build --tag ghcr.io/gombos/usrlocal --file ~/.dotfiles/containers/Dockerfile-usrlocal             ~/.dotfiles/
  docker push     ghcr.io/gombos/usrlocal
fi

if echo $TARGET | grep -w -q iso; then
  DOCKER_BUILDKIT=1 docker build --tag ghcr.io/gombos/iso --file ~/.dotfiles/containers/Dockerfile-iso             ~/.dotfiles/
  docker push     ghcr.io/gombos/iso
fi

#if echo $TARGET | grep -w -q convertefi ; then
#  DOCKER_BUILDKIT=1 docker build --tag ghcr.io/gombos/efi --file ~/.dotfiles/containers/Dockerfile-convertefi              ~/.dotfiles/
#  docker push     ghcr.io/gombos/efi
#fi
