if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
# Lima BEGIN
# Make sure iptables and mount.fuse3 are available
PATH="$PATH:/usr/sbin:/sbin"
export PATH
# Lima END

if [ -e /home/user.linux/.nix-profile/etc/profile.d/nix.sh ]; then . /home/user.linux/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

if [ -e $HOME/.venv/bin/activate ]; then . $HOME/.venv/bin/activate; fi #python venv
