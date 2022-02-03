#!/bin/bash

# Remove files or directories or touch files - no ther logic should be here
# Todo - Update integrity

# Idenpotent

if [ -d "$1" ]; then
  cd "$1"
else
  cd $MNTDIR/linux/linux
fi

if [ "$EUID" -ne 0 ]; then
  RM="sudo rm -rf"
  EMPTY="true | sudo tee"
else
  RM="rm -rf"
  EMPTY="true | tee"
fi

empty_file() {
  if [ -f "$1" ]; then
    eval "$EMPTY $1"
  fi
}

rm_file() {
  echo "$RM" $1
  eval "$RM" $1
}

image_clean_function() {
    rm_file etc/apt/trusted.gpg~
    rm_file etc/group-
    rm_file etc/gshadow-
    rm_file etc/passwd-
    rm_file etc/shadow-
    rm_file etc/subgid-
    rm_file etc/subuid-
    rm_file etc/apt/apt.conf.d/01autoremove-kernels

    rm_file 'root/{*,.*}'
    rm_file 'var/cache/*'
    mkdir -p var/cache/apt/archives/partial
    rm_file 'var/lib/dhcp/*'
    rm_file 'var/lib/apt/lists/*'
    rm_file var/lib/command-not-found/commands.db.metadata
    rm_file 'var/lib/dpkg/*-old'
    rm_file 'var/log/apt/*'
    rm_file 'var/log/journal/*'
    rm_file var/log/fontconfig.log
    rm_file var/log/alternatives.log
    rm_file var/log/dpkg.log
    rm_file var/log/vmware-installer
    rm_file 'var/log/vmware/*'
    rm_file var/log/vnetlib

    rm_file 'var/log/Xorg.0.log*'
    rm_file var/log/bootstrap.log

    rm_file 'var/backups/*'

    rm_file 'var/lib/sudo/*'
    rm_file 'var/lib/dkms/*'
    rm_file var/lib/ucf/cache
    rm_file 'var/lib/ucf/hashfile.*'
    rm_file 'var/lib/ucf/registry.*'
    rm_file 'var/spool/postfix/maildrop/*'
    rm_file 'var/log/nginx/*'
    rm_file var/lib/systemd/catalog/database
    rm_file var/cache/ldconfig/aux-cache

    # Empty files instead of deleting them
    empty_file var/log/faillog
    empty_file var/log/lastlog
    empty_file var/log/wtmp
    empty_file var/log/btmp

    rm_file .dockerenv
    rm_file 'root/{*,.*}'
    rm_file 'etc/ssh/ssh_host*'
    rm_file 'core*'
}

find . -name *.pyc -delete
find . -name __pycache__ -delete

[ -f etc/hostname ] && sudo rm -f etc/hostname 2>/dev/null || true

image_clean_function
