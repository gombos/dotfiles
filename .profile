export PATH="/home/linuxbrew/.linuxbrew/opt/portable-ruby/bin:$PATH"

export HOMEBREW_NO_ENV_HINTS=1

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

export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export HOMEBREW_NO_ANALYTICS=1
export PATH="/home/linuxbrew/.linuxbrew/opt/portable-ruby/bin:$PATH"
