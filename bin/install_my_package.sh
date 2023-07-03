if [ -f /usr/bin/apt-get ]; then
  apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 "$@"
  exit 0
fi

if [ -f /usr/sbin/aur-install ]; then
  /usr/sbin/aur-install "$@"
  exit 0
fi

if [ -f /usr/local/bin/pacapt ]; then
  if [ "$ID" = "alpine" ]; then
    /usr/local/bin/pacapt -Sy "$@"
  else
    /usr/local/bin/pacapt -Sy --noconfirm "$@"
  fi
fi
