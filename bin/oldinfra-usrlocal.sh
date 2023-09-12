#!/bin/sh

cp $REPO/bin/* /tmp/
cp $REPO/packages/* /tmp/
cd /tmp

TMPUSRLOCAL=/tmp/usrlocal
rm -rf $TMPUSRLOCAL && mkdir $TMPUSRLOCAL && cd $TMPUSRLOCAL
. /tmp/packages-usrlocal
mksquashfs /usr/local /tmp/usrlocal.img -comp zstd

ls -la /tmp/usrlocal.img
