#!/bin/bash

# Setup symbolic links to my .dotfiles

cwd=$HOME

cd $cwd

ln .dotfiles/.bashrc
ln .dotfiles/.profile
ln .dotfiles/.inputrc
ln .dotfiles/.hushlogin

ln .dotfiles/.gtkrc-2.0
ln .dotfiles/.mailcap
ln .dotfiles/.Xresources
ln .dotfiles/.xsessionrc
ln .dotfiles/.Xmodmap
ln .dotfiles/.gitconfig

ln .dotfiles/.Xresources-HiDPI

cd $cwd
mkdir -p .config
cd .config
ln ../.dotfiles/.config/mimeapps.list
ln ../.dotfiles/.config/openbox
ln ../.dotfiles/.config/libfm

cd $cwd
mkdir -p .local/share/applications/
cd .local/share/applications/
ln ../../../.dotfiles/.local/share/applications/editor.desktop
ln ../../../.dotfiles/.local/share/applications/web.desktop
ln ../../../.dotfiles/.local/share/applications/web-incognito.desktop

cd $cwd
mkdir -p .config/kitty
cd .config/kitty
ln ../../.dotfiles/.config/kitty/kitty.conf

cd $cwd
mkdir -p .config/micro
cd .config/micro
ln ../../.dotfiles/.config/micro/bindings.json
ln ../../.dotfiles/.config/micro/settings.json

# VS code
cd $cwd
mkdir -p .config/Code/User
cd .config/Code/User
ln ../../../.dotfiles/.config/Code/User/settings.json
ln ../../../.dotfiles/.config/Code/User/keybindings.json

# panel
cd $cwd
mkdir -p .config/lxpanel/default/panels
cd .config/lxpanel/default/panels
ln ../../../../.dotfiles/.config/lxpanel/default/panels/panel

cd $cwd
rm -rf .bash_profile

echo "User provisioning is finished, please log out and log back in again."
