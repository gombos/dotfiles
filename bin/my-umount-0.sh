#!/bin/sh

sudo umount ~/0
sudo cryptsetup close 0
sudo umount ~/.disk0

rmdir ~/0
rmdir ~/.disk0
