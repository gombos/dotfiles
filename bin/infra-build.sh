#!/bin/sh

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/build-infra.log 2>&1

. infra-env.sh

if ! [ -z "$1" ]; then
  TARGET="$1"
else
  TARGET="iso"
fi

if echo $TARGET | grep -w -q kernel; then
  docker build -t ghcr.io/gombos/kernel     ~/.dotfiles/ -f ~/.dotfiles/containers/Dockerfile-kernel
  docker push     ghcr.io/gombos/kernel
fi
