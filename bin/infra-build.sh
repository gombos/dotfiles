#!/bin/sh

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/tmp/build-infra.log 2>&1

. infra-env.sh

# "boot minbase container base preconfig rootfs"

if ! [ -z "$1" ]; then
  TARGET="$1"
else
  TARGET="rootfs"
fi

if echo $TARGET | grep -w -q efi; then
  docker build -t 0gombi0/homelab:efi     ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-efi
  docker push 0gombi0/homelab:efi
fi

if echo $TARGET | grep -w -q minbase; then
  sudo rm -rf /tmp/minbase
  sudo LANG=C debootstrap --variant=minbase --components=main,universe --exclude=procps,libprocps8,usrmerge,sensible-utils $RELEASE /tmp/minbase
  sudo rm -rf /tmp/minbase/var/cache /tmp/minbase/var/log/* /tmp/minbase/var/lib/apt/ /tmp/minbase/var/lib/systemd
  sudo mkdir -p /tmp/minbase//var/cache/apt/archives/partial
  cd /tmp/minbase && sudo tar -c . | docker import - 0gombi0/homelab:minbase && cd -
  docker push 0gombi0/homelab:minbase
  sudo rm -rf /tmp/minbase
fi

# not needed for iso
if echo $TARGET | grep -w -q container; then
  docker build -t 0gombi0/homelab:latest    ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-container
  docker push 0gombi0/homelab:latest
fi

if echo $TARGET | grep -w -q base; then
  docker build -t 0gombi0/homelab-baremetal:vm    ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-base
  docker push 0gombi0/homelab-baremetal:vm
fi

if echo $TARGET | grep -w -q preconfig; then
  docker build -t 0gombi0/homelab-baremetal:rootfs-preconfig     ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-laptop
  docker push 0gombi0/homelab-baremetal:rootfs-preconfig
fi

if echo $TARGET | grep -w -q rootfs; then
  docker build -t 0gombi0/homelab-baremetal:rootfs     ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-laptop-config
  docker push 0gombi0/homelab-baremetal:rootfs
  sudo rm -rf /tmp/laptop /tmp/squashfs.img
  mkdir -p /tmp/laptop
  infra-get-rootfs.sh /tmp/laptop
  sudo mksquashfs /tmp/laptop /tmp/squashfs.img -comp zstd
  sudo tar -c /tmp/squashfs.img | docker import - 0gombi0/homelab-baremetal:squashfs
  docker push 0gombi0/homelab-baremetal:squashfs
  sudo rm -rf /tmp/laptop
fi

if echo $TARGET | grep -w -q nix; then
  docker build -t 0gombi0/homelab:nix     ~/.dotfiles/ -f ~/.dotfiles/.Dockerfile-homelab-nix
  docker push 0gombi0/homelab:nix
fi

if echo $TARGET | grep -w -q iso; then
  infra-image.sh
#  sudo tar -c /tmp/*.iso | docker import - 0gombi0/homelab:iso
#  docker push 0gombi0/homelab:iso
fi
