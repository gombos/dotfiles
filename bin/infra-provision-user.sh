#!/bin/bash

# Setup symbolic links to my .dotfiles

HOST=$(hostname)

cd

ln -sf ~/.dotfiles/.bashrc
ln -sf ~/.dotfiles/.hushlogin
ln -sf ~/.dotfiles/.inputrc
ln -sf ~/.dotfiles/.profile
ln -sf ~/.dotfiles/.mime.types

if [ -f /usr/lib/xorg/Xorg ]; then
  ln -sf ~/.dotfiles/.gtkrc-2.0
  ln -sf ~/.dotfiles/.mailcap
  ln -sf ~/.dotfiles/.Xresources
  ln -sf ~/.dotfiles/.xsessionrc

  if test "$HOST" = 'bagoly' || test "$HOST" = 'bestia'; then
    ln -sf ~/.dotfiles/.Xresources-HiDPI
  fi

  mkdir -p ~/.local/share/applications/
  cd ~/.local/share/applications/

  ln -sf ~/.dotfiles/.local/share/applications/editor.desktop
  ln -sf ~/.dotfiles/.local/share/applications/web.desktop
  ln -sf ~/.dotfiles/.local/share/applications/web-incognito.desktop

  # Code
  mkdir -p ~/.config/Code/User
  cd ~/.config/Code/User
  ln -sf ~/.dotfiles/.config/Code/User/settings.json
  ln -sf ~/.dotfiles/.config/Code/User/keybindings.json

  # panel
  mkdir -p ~/.config/lxpanel/default/panels
  cd ~/.config/lxpanel/default/panels
  ln -sf ~/.dotfiles/.config/lxpanel/default/panels/panel

  # mime
  cd ~/.config/
  ln -sf ~/.dotfiles/.config/mimeapps.list

  # openbox
  mkdir -p ~/.config
  cd ~/.config
  ln -sf ~/.dotfiles/.config/openbox

  # libfm
  mkdir -p ~/.config
  cd ~/.config
  ln -sf ~/.dotfiles/.config/libfm
fi

# cleanup
rm ~/.bash_profile
cd

echo "User provisioning is finished, please log out and log back in again."

#if [ "$HOST" == pincer ]; then
#  sudo apt-get update
#  sudo apt-get install python-setuptools python-dev python-pip
#  sudo apt-get install build-essential libffi-dev libusb-1.0-0 libusb-1.0-0-dev
#  pip install wheel
#  pip install ouimeaux
#  pip install snmp-passpersist
#  pip install temperusb
#
#  # log dir
#  mkdir ~/temperature
#  croncmd="/home/user/.dotfiles/.bin/temperature-control.sh"
#  cronjob="*/1 * * * * $croncmd"
#  ( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -
#fi
