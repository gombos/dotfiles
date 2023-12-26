#!/bin/sh

if [ -f /bin/dnf ]; then
  exit
fi

if [ -f /usr/local/bin/pacapt ]; then
  /usr/local/bin/pacapt -Sy
fi

if [ -f /usr/bin/apt-get  ]; then
  apt-get update -y -qq -o Dpkg::Use-Pty=0
fi
