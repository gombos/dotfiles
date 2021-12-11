  if [ -f /usr/bin/apt-get ]; then
    apt-get install -y -qq --no-install-recommends -o Dpkg::Use-Pty=0 "$@"
  else
    if [ -f usr/local/bin/pacapt ]; then
      if [ "$ID" = "alpine" ]; then
        usr/local/bin/pacapt -S "$@"
      else
        usr/local/bin/pacapt -S --noconfirm "$@"
      fi
    fi
  fi
