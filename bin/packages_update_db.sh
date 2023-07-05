#!/bin/sh

if [ -f /usr/local/bin/pacapt ]; then
  /usr/local/bin/pacapt -Sy
else
  apt-get update -y -qq -o Dpkg::Use-Pty=0
fi
