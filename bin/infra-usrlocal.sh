#!/bin/sh

cp $REPO/bin/* /tmp/
cp $REPO/packages/* /tmp/
cd /tmp

TMPUSRLOCAL=/tmp/usrlocal
rm -rf $TMPUSRLOCAL && mkdir $TMPUSRLOCAL && cd $TMPUSRLOCAL
./packages-usrlocal
mksquashfs $TMPUSRLOCAL /tmp/usrlocal.img -comp zstd
find /tmp
find $TMPUSRLOCAL