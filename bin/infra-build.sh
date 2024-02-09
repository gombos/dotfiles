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

# todo - use mkosi instead
if echo $TARGET | grep -w -q minbase; then
  sudo rm -rf /tmp/minbase
  sudo LANG=C debootstrap --variant=minbase --components=main,universe $RELEASE /tmp/minbase
  sudo rm -rf /tmp/minbase/var/cache /tmp/minbase/var/log/* /tmp/minbase/var/lib/apt/ /tmp/minbase/var/lib/systemd
  sudo mkdir -p /tmp/minbase/var/cache/apt/archives/partial
  cd /tmp/minbase && sudo tar -c . | docker import - ghcr.io/gombos/base:$RELEASE && cd -
  docker push ghcr.io/gombos/base:$RELEASE
  sudo rm -rf /tmp/minbase
fi
