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

export VIRTUAL_ENV=/opt/venv
if [ -e /opt/venv/bin/activate ]; then . /opt/venv/bin/activate; fi #python venv
