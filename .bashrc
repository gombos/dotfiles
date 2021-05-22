# ~/.bashrc: executed by bash(1) for non-login shells.

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
  if [ $(hostname) != "localhost" ] && [ $(hostname) != "taska.local" ] ; then
    echo -n $(hostname); echo -n ':';
  fi
}

PS1='\[\033[01;32m\]$(psusername)\[\033[01;34m\]$(pshostname)\w\[\033[00m\] '

# -- Configure the environment for childs

# Eternal bash history
export HISTFILESIZE=
export HISTSIZE=
export HISTTIMEFORMAT="[%F %T] "
export HISTFILE=~/.eternal_history

# less
export LESSHISTSIZE=0
export PAGER=less

# Mount point, rw access for all users
export MNTDIR="/run/media"

# Only my user has access
export RUNDIR="/run/user/$UID"

export BASH_SILENCE_DEPRECATION_WARNING=1

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH:."
fi

if [ -d "$HOME/.dotfiles/bin" ] ; then
    PATH="$HOME/.dotfiles/bin:$PATH:."
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
alias docker='sudo docker'
alias qiv='qiv -tfi --browse --autorotate'
alias df='df -h'
alias vd='vd -f csv'
alias finance='EDITOR="vd -f csv" pass edit'
alias wake-bestia='ssh pincer-wan wake-bestia'

# -- Source externel files

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
fi

# lesspipe
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
[ -x /usr/local/bin/lesspipe.sh ] && export LESSOPEN="|/usr/local/bin/lesspipe.sh %s"

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# One letter acions (CLI)

# BTRFS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
 s()  { systemctl suspend -i; }
fi

#run-mailcap
#lesspipe
# plan - https://news.ycombinator.com/item?id=20196982
# though this tool does a lot more (caching, recursing into archives and extracting all text) and is a lot faster (for the file types it can parse, lesspipe knows more), and of course lesspipe is only indirectly usable for recursive searching.
# todo sudo apt install recollgui - vs rga

# X11 aliases
alias stop-session='openbox --exit'

alias net-on='sudo ifup -a; ifconfig'
alias net-off='sudo ifdown -a'

alias REALLYclean='git clean -xfd; git reset --hard; git gc --aggressive --prune; find . -type f -name "*~" -exec rm -f {} \;'
alias Testclean='git clean -xfdn; find . -type f -name "*~" -exec ls {} \;'

# Keep this at the end
# Allow different environment scripts to run
#local_scripts=`ls ~/.env-* 2>/dev/null`
#if [ ! -z "$local_scripts" ]; then
#  for f in ~/.env-*; do source $f; done
#fi

if [ -f "/google/devshell/bashrc.google" ]; then
  source "/google/devshell/bashrc.google"
fi

if [ -e /home/user/.nix-profile/etc/profile.d/nix.sh ]; then . /home/user/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

if [ -e ~/.dotfiles/bin/env-$(hostname) ]; then . ~/.dotfiles/bin/env-$(hostname); fi # added by Nix installer

alias mnt-1="sshfs bestia:$MNTDIR/data ~/1"
alias umnt-1="sudo umount ~/1"
alias lsb="lsblk -o name,partlabel,label,mountpoint,fstype,size,fsavail,fsuse%,uuid"

# TODO - write a generic backup functiona that discovers on which machine it runs and it acts accordingly

alias python=python3

go-d() { cd ~/.dotfiles; }

