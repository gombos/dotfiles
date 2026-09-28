# brew
export PATH="/home/linuxbrew/.linuxbrew/opt/portable-ruby/bin:$PATH"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ANALYTICS=1

# Lima BEGIN
# Make sure iptables and mount.fuse3 are available
PATH="$PATH:/usr/sbin:/sbin"
export PATH
# Lima END

# nix
if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then . ~/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

if [ -e /home/usr/.nix-profile/etc/profile.d/nix.sh ]; then . /home/usr/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer
