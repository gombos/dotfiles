#!/bin/sh

# Script executed during ram disk phase (rd.exec = ram disk execute)
#. /lib/dracut-lib.sh

RDEXEC="/usr/bin/infra-init.sh"

if [ -f "$RDEXEC" ]; then
  # Execute the rd.exec script in a sub-shell
  printf "[rd.exec] start executing $RDEXEC \n"
  scriptname="${RDEXEC##*/}"
  scriptpath=${RDEXEC%/*}
  configdir="$scriptpath"
  ( cd $configdir && . "./$scriptname" )
  printf "[rd.exec] stop executing $RDEXEC \n"
fi
