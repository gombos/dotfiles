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
  TARGET="boot initrd kernel kernelinitramfs minbase base extra config usrlocal iso"
fi

if echo $TARGET | grep -w -q initrd; then
  docker build -t 0gombi0/homelab:initrd     ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-homelab-initrd
  docker push 0gombi0/homelab:initrd
fi

if echo $TARGET | grep -w -q kernel; then
  docker build -t 0gombi0/homelab:kernel     ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-kernel
  #docker build -t 0gombi0/homelab:kernel     ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-homelab-kernel
  docker push 0gombi0/homelab:kernel
fi

if echo $TARGET | grep -w -q kernelinitramfs; then
  docker build -t 0gombi0/homelab:kernel     ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-kernelinitramfs
  docker push 0gombi0/homelab:kernel
fi

if echo $TARGET | grep -w -q minbase; then
  sudo rm -rf /tmp/minbase
  sudo LANG=C debootstrap --variant=minbase --components=main,universe --exclude=procps,libprocps8,usrmerge,sensible-utils $RELEASE /tmp/minbase
  sudo rm -rf /tmp/minbase/var/cache /tmp/minbase/var/log/* /tmp/minbase/var/lib/apt/ /tmp/minbase/var/lib/systemd
  sudo mkdir -p /tmp/minbase/var/cache/apt/archives/partial
  cd /tmp/minbase && sudo tar -c . | docker import - 0gombi0/homelab:minbase && cd -
  docker push 0gombi0/homelab:minbase
  sudo rm -rf /tmp/minbase
fi

if echo $TARGET | grep -w -q container; then
  docker build -t 0gombi0/homelab:latest    ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-homelab-container
  docker push     0gombi0/homelab:latest
fi

if echo $TARGET | grep -w -q base; then
  docker build -t 0gombi0/homelab-baremetal:base    ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-homelab-base
  docker push     0gombi0/homelab-baremetal:base
fi

if echo $TARGET | grep -w -q extra; then
  docker build -t 0gombi0/homelab-baremetal:extra     ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-homelab-extra
  docker push     0gombi0/homelab-baremetal:extra
fi

if echo $TARGET | grep -w -q config; then
  docker build -t 0gombi0/homelab-baremetal:latest     ~/.dotfiles/ -f ~/.dotfiles/containers/.Dockerfile-homelab-config
  docker push     0gombi0/homelab-baremetal:latest
fi

if echo $TARGET | grep -w -q usrlocal; then
  TMPUSRLOCAL=/tmp/usrlocal
  sudo rm -rf $TMPUSRLOCAL && sudo mkdir $TMPUSRLOCAL && cd $TMPUSRLOCAL
  docker run --privileged --device /dev/fuse --cap-add SYS_ADMIN -v $TMPUSRLOCAL:/usr/local -v ~/.dotfiles/bin/:/tmp/bin 0gombi0/homelab-baremetal:extra /tmp/bin/packages-usrlocal
  sudo mksquashfs $TMPUSRLOCAL /tmp/usrlocal.img -comp zstd
  #gh release upload --clobber -R gombos/dotfiles usrlocal /tmp/usrlocal.img
fi

if echo $TARGET | grep -w -q iso; then
  infra-image.sh
fi

if echo $TARGET | grep -w -q upload; then
  gh release upload --clobber -R gombos/dotfiles iso /tmp/linux.iso
fi
