#!/bin/sh

if [ -f usr/local/bin/pacapt ]; then
  usr/local/bin/pacapt -Suy
fi

apt-get upgrade -y -qq -o Dpkg::Use-Pty=0
