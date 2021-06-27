#!/bin/sh

mkdir -p $1

# todo - should not need to specify exclude here

LC_ALL=C find . -mount -type f -not -path "./tmp/*" -not -path "./run/*" -not -path "./etc/hostname" -not -path "./etc/resolv.conf" -exec md5sum "{}" + | sed 's/  \.\//  /' | sort --key=2 > /tmp/rootfs.chk
LC_ALL=C find . -mount -type l -not -path "./tmp/*" -not -path "./run/*" -exec ls -lQ {} \; | cut -d\" -f2-4 | sed 's/^\.\///' > sort > /tmp/rootfs-links.chk
LC_ALL=C find . -mount -type d -empty | sed 's/^\.\///' | sort > /tmp/rootfs-dirs.chk

cat /tmp/rootfs.chk /tmp/rootfs-links.chk /tmp/rootfs-dirs.chk | md5sum | head -c 4 > /tmp/id

mv /tmp/rootfs*.chk /tmp/id $1
