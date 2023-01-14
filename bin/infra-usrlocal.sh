#!/bin/sh

if ! [ -z "$REPO" ]; then
  cp $REPO/bin/* /tmp/
  cp $REPO/packages/* /tmp/
  cd /tmp
fi

TMPUSRLOCAL=/tmp/usrlocal
sudo rm -rf $TMPUSRLOCAL && sudo mkdir $TMPUSRLOCAL && cd $TMPUSRLOCAL
docker run --privileged --device /dev/fuse --cap-add SYS_ADMIN -v $TMPUSRLOCAL:/usr/local -v ~/.dotfiles/bin/:/tmp/bin 0gombi0/homelab-baremetal:extra /tmp/bin/packages-usrlocal
sudo mksquashfs $TMPUSRLOCAL /tmp/usrlocal.img -comp zstd
