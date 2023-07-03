if [ -f /usr/bin/apt-get ]; then
  apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 "$@"
  return
fi

if [ -f /usr/bin/paru ]; then
  /usr/bin/paru /usr/local/bin/pacapt -Sy --noconfirm "$@"
  return
fi

if [ -f /usr/local/bin/pacapt ]; then
  if [ "$ID" = "alpine" ]; then
    /usr/local/bin/pacapt -Sy "$@"
  else
    /usr/local/bin/pacapt -Sy --noconfirm "$@"
  fi
fi
