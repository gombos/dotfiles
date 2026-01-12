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

export VIRTUAL_ENV=/opt/venv
export VIRTUAL_ENV_DISABLE_PROMPT=1
if [ -e /opt/venv/bin/activate ]; then . /opt/venv/bin/activate; fi #python venv

export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export HOMEBREW_NO_ANALYTICS=1
