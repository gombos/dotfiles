# ~/.bashrc: executed by bash(1) for non-login shells.

PATH="$PATH:/usr/sbin:/sbin"
export PATH

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
  if [ $UID != 501 ] && [ $UID != 1000 ] && [ $UID != 1561434206 ]; then
    echo -n $USER; echo -n ':';
  fi
}

# command prompt hostname
function pshostname {
  if [ $HOSTNAME != "localhost" ] && [ $HOSTNAME != "mac.lan" ]  && [ $HOSTNAME != "2033000807" ] ; then
    echo -n $HOSTNAME; echo -n ':';
  fi
}

PS1='\[\033[01;32m\]$(psusername)\[\033[01;34m\]\w\[\033[00m\] '

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
alias flatpak='sudo flatpak'
alias qiv='qiv -tfi --browse --autorotate'
alias df='df -h'
alias finance='EDITOR="vd -f csv" pass edit'

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

# Color
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b)"
fi

alias ls='ls --color=always'
alias grep='grep --color=auto'
alias less='less -R'
alias ll='ls -lt --color=always | head -20'

# lesspipe
# todo - figure out how to make lesspipe and bash-completition work together
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
#[ -x /usr/local/bin/lesspipe.sh ] && export LESSOPEN="|/usr/local/bin/lesspipe.sh %s"

# nix
#if [ -e /nix ]; then
#  if ! [ -e ~/.nix-profile ]; then ln -sf /nix/var/nix/profiles/per-user/root/profile ~/.nix-profile; fi
#  if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then . ~/.nix-profile/etc/profile.d/nix.sh; fi
#  rm -rf ~/.nix-channels ~/.nix-defexpr
#  nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
#fi

# host specific
#if [ -e $DOTFILES/bin/env-$(hostname) ]; then . $DOTFILES/bin/env-$(hostname); fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  alias lb="ssh -F ~/.colima/ssh_config colima"
  alias find='gfind'

  function l {
    ssh -F ~/.colima/ssh_config colima -t distrobox-enter
  }
fi

export LESSHISTFILE=-

# Lima BEGIN
# Make sure iptables and mount.fuse3 are available
PATH="$PATH:/usr/sbin:/sbin"
export PATH
# Lima END
