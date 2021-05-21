# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

if [ -d "/storage/repo/depot_tools" ] ; then
    PATH="$PATH:/storage/repo/depot_tools"
fi

# set PATH so it includes user's private bin (e.g. for pip) if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH:."
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.dotfiles/bin" ] ; then
    PATH="$HOME/.dotfiles/bin:$PATH:."
fi

export TZ='America/New_York'

export BASH_SILENCE_DEPRECATION_WARNING=1

if type brew &>/dev/null; then
  HOMEBREW_PREFIX="$(brew --prefix)"
  if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
    source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
      [[ -r "$COMPLETION" ]] && source "$COMPLETION"
    done
  fi
fi


if [ -e /home/linuxbrew/.linuxbrew/bin/brew ]; then eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv); fi
