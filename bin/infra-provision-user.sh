#!/bin/bash

# Setup symbolic links to my .dotfiles

cwd=$(pwd)

cd $cwd

ln -sf .dotfiles/.bashrc
ln -sf .dotfiles/.profile
ln -sf .dotfiles/.inputrc
ln -sf .dotfiles/.hushlogin

ln -sf .dotfiles/.gtkrc-2.0
ln -sf .dotfiles/.mailcap
ln -sf .dotfiles/.Xresources
ln -sf .dotfiles/.xsessionrc
ln -sf .dotfiles/.Xmodmap

ln -sf .dotfiles/.Xresources-HiDPI

cd $cwd
mkdir -p .config
cd .config
ln -sf ../.dotfiles/.config/mimeapps.list
ln -sf ../.dotfiles/.config/openbox
ln -sf ../.dotfiles/.config/libfm

cd $cwd
mkdir -p .local/share/applications/
cd .local/share/applications/
ln -sf ../../../.dotfiles/.local/share/applications/editor.desktop
ln -sf ../../../.dotfiles/.local/share/applications/web.desktop
ln -sf ../../../.dotfiles/.local/share/applications/web-incognito.desktop

cd $cwd
mkdir -p .config/micro
cd .config/micro
ln -sf ../../.dotfiles/.config/micro/bindings.json
ln -sf ../../.dotfiles/.config/micro/settings.json

# Code
cd $cwd
mkdir -p .config/Code/User
cd .config/Code/User
ln -sf ../../../.dotfiles/.config/Code/User/settings.json
ln -sf ../../../.dotfiles/.config/Code/User/keybindings.json

# panel
cd $cwd
mkdir -p .config/lxpanel/default/panels
cd .config/lxpanel/default/panels
ln -sf ../../../../.dotfiles/.config/lxpanel/default/panels/panel

cd $cwd
rm .bash_profile

echo "User provisioning is finished, please log out and log back in again."

#if [ "$HOST" == pincer ]; then
#  # log dir
#  mkdir ~/temperature
#  croncmd="/home/user/.dotfiles/.bin/temperature-control.sh"
#  cronjob="*/1 * * * * $croncmd"
#  ( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -
#fi
