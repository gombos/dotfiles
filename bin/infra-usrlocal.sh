#!/bin/sh

cp $REPO/bin/* /tmp/
cp $REPO/packages/* /tmp/
cd /tmp

find .

TMPUSRLOCAL=/tmp/usrlocal
rm -rf $TMPUSRLOCAL && mkdir $TMPUSRLOCAL && cd $TMPUSRLOCAL
. /tmp/packages-usrlocal
mksquashfs $TMPUSRLOCAL /tmp/usrlocal.img -comp zstd
find /tmp
find $TMPUSRLOCAL

ls -la /tmp/usrlocal.img
