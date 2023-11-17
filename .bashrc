# ~/.bashrc: executed by bash(1) for non-login shells.

export DOTFILES="$HOME/.dotfiles"

if [ -d "$DOTFILES/bin" ] ; then
  export PATH="$DOTFILES/bin:$PATH"
fi

if [ -d "/usr/local/sbin" ] ; then
  export PATH="$PATH:/usr/local/sbin"
fi

if [ -d "/opt/homebrew/bin" ] ; then
  eval $(/opt/homebrew/bin/brew shellenv)
fi

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# -- Configure bash

# key binding to exit the shell (on an empty line) - ctrl+q instead of ctrl+d
stty eof \^q

# key binding to interrupt execution or empty the line
stty intr \^d

#I typically use stty -ixon -ixoff so I can reclaim the CTRL-S and CTRL-Q key bindings for more modern purposes
stty -ixon -ixoff

# command prompt username
function psusername {
  if [ $UID != 1000 ] ; then
    echo -n $USER; echo -n ':';
  fi
}

# command prompt hostname
function pshostname {
  if [ $HOSTNAME != "localhost" ] && [ $HOSTNAME != "taska.kucko" ]  ; then
    echo -n $HOSTNAME; echo -n ':';
  fi
}

#PS1='\[\033[01;32m\]$(psusername)\[\033[01;34m\]\w\[\033[00m\] '
PS1='\[\033[01;32m\]$(psusername)\[\033[01;34m\]$(pshostname)\w\[\033[00m\] '

# -- Configure the environment for childs

# Eternal bash history
export HISTFILESIZE=
export HISTSIZE=
export HISTTIMEFORMAT="[%F %T] "
export HISTFILE=~/.eternal_history

export BASH_SILENCE_DEPRECATION_WARNING=1

# less
export LESSHISTSIZE=0
export PAGER=less

# Mount point, rw access for all users
export MNTDIR="/run/media"

# Only my user has access
export RUNDIR="/run/user/$UID"

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH:."
fi

if [ -d "/storage/repo/depot_tools" ] ; then
    PATH="$PATH:/storage/repo/depot_tools"
fi

# default editor
if command -v micro &> /dev/null
then
  export VISUAL='micro'
  export EDITOR=$VISUAL
  export GIT_EDITOR=$VISUAL
fi

# -- Aliases (only for interactive use)

# page file - read only view, paginate, search
alias v=$PAGER

# edit file
alias e=$VISUAL

# search driectory
alias search='rga'

# Default arguments
alias apt='sudo apt'
alias iotop='sudo iotop'
alias qiv='qiv -tfi --browse --autorotate'
alias df='df -h'
alias vd='vd -f csv'
alias finance='EDITOR="vd -f csv" pass edit'
alias wake-bestia='ssh kispincer-wan wake-bestia'

alias stop-session='openbox --exit'

alias net-on='sudo ifup -a; ifconfig'
alias net-off='sudo ifdown -a'

alias REALLYclean='git clean -xfd; git reset --hard; git gc --aggressive --prune; find . -type f -name "*~" -exec rm -f {} \;'
alias Testclean='git clean -xfdn; find . -type f -name "*~" -exec ls {} \;'

alias mnt-1="sshfs bestia:$MNTDIR/data ~/1"
alias umnt-1="sudo umount ~/1"
alias lsb="lsblk -o name,mountpoint,partlabel,label,fstype,size,fsavail,fsuse% | grep -v swap"

alias config='/usr/bin/git --git-dir=$DOTFILES --work-tree=$DOTFILES'

# -- Source externel files

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

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

# google-cloud-sdk on MacOS (brew)
if [ -x /usr/local/Caskroom/google-cloud-sdk ]; then
    export CLOUDSDK_PYTHON="/usr/local/opt/python@3.9/libexec/bin/python"
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc"
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc"
fi

# Color
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias less='less -R'
fi

# lesspipe
# todo - figure out how to make lesspipe and bash-completition work together
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
#[ -x /usr/local/bin/lesspipe.sh ] && export LESSOPEN="|/usr/local/bin/lesspipe.sh %s"

if [ -f "/google/devshell/bashrc.google" ]; then
  source "/google/devshell/bashrc.google"
fi

# brew packages
if [ -e /home/linuxbrew/.linuxbrew/bin/brew ]; then eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv); fi
#if [ -e .linuxbrew/bin/brew ]; then eval $(.linuxbrew/bin/brew shellenv); fi

# nix packages
if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then . ~/.nix-profile/etc/profile.d/nix.sh; fi

# host specific
#if [ -e $DOTFILES/bin/env-$(hostname) ]; then . $DOTFILES/bin/env-$(hostname); fi

# TODO
#. "$HOME/.cargo/env"

if [[ "$OSTYPE" == "darwin"* ]]; then
  alias linux="ssh -F ~/.colima/ssh_config colima"
fi
# Lima BEGIN
# Make sure iptables and mount.fuse3 are available
PATH="$PATH:/usr/sbin:/sbin"
export PATH
# Lima END
