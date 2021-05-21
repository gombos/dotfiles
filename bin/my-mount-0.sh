#!/bin/sh

mkdir -p ~/.disk0
mount ~/.disk0
sudo cryptsetup open --type tcrypt ~/.disk0/0 0

mkdir -p ~/0
sudo mount /dev/mapper/0 ~/0 -o user,uid=$(id -u),gid=$(id -g),fmask=0177,dmask=0077,noexec,nosuid,nodev
