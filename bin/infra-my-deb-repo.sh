#!/bin/bash

for i in $(dpkg -l |grep ^ii |awk -F' ' '{print $2}'); do
  apt-cache showpkg "$i"|head -3|grep -v '^Versions'|cut -d'(' -f2|cut -d')' -f1|sed -e 's/^Package: //;' | paste -d '\t' - -
done
  
#aptitude search "~i" -F "%s# %p"

