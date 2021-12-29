  if [ -f usr/local/bin/pacapt ]; then
    usr/local/bin/pacapt -R --noconfirm "$1"
  else
    apt-get purge -y -qq -o Dpkg::Use-Pty=0 "$1"
  fi
