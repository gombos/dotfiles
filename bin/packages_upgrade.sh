#!/bin/sh

if [ -f /bin/dnf ]; then
  dnf -y update
fi

if [ -f usr/local/bin/pacapt ]; then
  usr/local/bin/pacapt -Suy
fi

if [ -f /usr/bin/apt-get  ]; then
  apt-get upgrade -y -qq -o Dpkg::Use-Pty=0
fi
