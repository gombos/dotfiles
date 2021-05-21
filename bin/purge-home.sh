#!/bin/bash

rm -rf ~/.anyconnect
rm -rf ~/.cache/
rm -rf ~/.dbus/
rm -rf ~/.gconf/
rm -rf ~/.java/
rm -rf ~/.joe_state
rm -rf ~/.local/
rm -rf ~/.pki/
rm -rf ~/.sudo_as_admin_successful
rm -rf ~/.thumbnails/
rm -rf ~/.tint2-crash.log
rm -rf ~/.xsession-errors
rm -rf ~/.icons
rm -rf ~/.gnome/
rm -rf ~/.*~
rm -rf ~/.jedrecent
rm -rf ~/.vscode/
rm -rf ~/.lesshst

Can be deleted selectivly
cd ~/.config/
find . | grep -v "google-chrome" | xargs rm -rf
~/.bin/bootstrap.sh

#todo:
#.bash_eternal_history
#.mozilla/
#.thunderbird/
#.vpn/
#.config/google-chrome
