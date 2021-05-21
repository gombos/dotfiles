#!/bin/sh

mkdir -p $1

# todo - should not need to specify exclude here

find . -mount -type f -not -path "./tmp/*" -not -path "./run/*" -not -path "./etc/hostname" -exec md5sum "{}" + | sed 's/  \.\//  /' > /tmp/rootfs.chk
find . -mount -type l -not -path "./tmp/*" -not -path "./run/*" -exec ls -lQ {} \; | cut -d\" -f2-4 | sed 's/^\.\///' > /tmp/rootfs-links.chk
find . -mount -type d -empty | sed 's/^\.\///' > /tmp/rootfs-dirs.chk

mv /tmp/rootfs*.chk $1
