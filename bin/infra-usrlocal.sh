#!/bin/sh

if ! [ -z "$REPO" ]; then
  cp $REPO/bin/* /tmp/
  cp $REPO/packages/* /tmp/
  cd /tmp
fi

TMPUSRLOCAL=/tmp/usrlocal
rm -rf $TMPUSRLOCAL && mkdir $TMPUSRLOCAL && cd $TMPUSRLOCAL
/tmp/packages-usrlocal
mksquashfs $TMPUSRLOCAL /tmp/usrlocal.img -comp zstd
