# brew
export PATH="/home/linuxbrew/.linuxbrew/opt/portable-ruby/bin:$PATH"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ANALYTICS=1

# nix has priority over brew
if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then . ~/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
