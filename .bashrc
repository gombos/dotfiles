# ~/.bashrc: executed by bash(1) for non-login shells.

# Logout on mac
# /System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# brew - google-cloud-sdk
if [ -x /usr/local/Caskroom/google-cloud-sdk ]; then
    export CLOUDSDK_PYTHON="/usr/local/opt/python@3.9/libexec/bin/python"
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc"
    source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc"
fi

# Check the window size after each command and if necessary
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Color support
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# lesspipe
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
[ -x /usr/local/bin/lesspipe.sh ] && export LESSOPEN="|/usr/local/bin/lesspipe.sh %s"

if command -v micro &> /dev/null
then
  export VISUAL='micro'
  alias joe=$VISUAL
  export EDITOR=$VISUAL
  export GIT_EDITOR=$VISUAL
  alias less='less -r'
  export PAGER=less
fi

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

# One letter acions (CLI)

# BTRFS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
 s()  { systemctl suspend -i; }
fi

# Open (edit) file or url as a graphical application
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  alias o='xdg-open'
elif [[ "$OSTYPE" == "darwin"* ]]; then
  alias o='open'
#  sl() { pmset sleepnow; }
fi

#run-mailcap
#lesspipe
# plan - https://news.ycombinator.com/item?id=20196982
# though this tool does a lot more (caching, recursing into archives and extracting all text) and is a lot faster (for the file types it can parse, lesspipe knows more), and of course lesspipe is only indirectly usable for recursive searching.
# todo sudo apt install recollgui - vs rga

# X11 aliases

alias stop-session='openbox --exit'

# Open with the associated app
#alias o='run-mailcap'

# Edit file
#alias xe='x-editor'

# Diff
#alias xdiff='diffuse'

alias net-on='sudo ifup -a; ifconfig'
alias net-off='sudo ifdown -a'

alias REALLYclean='git clean -xfd; git reset --hard; git gc --aggressive --prune; find . -type f -name "*~" -exec rm -f {} \;'
alias Testclean='git clean -xfdn; find . -type f -name "*~" -exec ls {} \;'

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# command promtp username
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

#if test "$(type -t __git_ps1)" = "function" ; then
#    branch_on_demand='echo -e "\e[32m"$(__git_ps1 "(%s) ")"\e[0m"'
#    branch_on_demand='$([ "$(__git_ps1 %s)" != "" -a "$(__git_ps1 %s)" != "master" ] && '"$branch_on_demand"' || :)'
#    PS1="${PS1%%\\\$ }$branch_on_demand"
#    unset branch_on_demand
#fi

# Eternal bash history.

# Undocumented feature which sets the size to "unlimited".
# http://stackoverflow.com/questions/9457233/unlimited-bash-history
export HISTFILESIZE=
export HISTSIZE=
export HISTTIMEFORMAT="[%F %T] "

# Change the file location because certain bash sessions truncate .bash_history file upon close.
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.eternal_history

# no lesshst
LESSHISTSIZE=0

#alias mupdf='mupdf -r 144'
#alias pe='pass edit'
#alias todo='pass edit todo'

#reboot-pincer() { ssh pincer-admin sudo reboot ; }

#bestia() {
#  ping -c1 -W1 bestia >/dev/null && ssh bestia || { wake-bestia && sleep 10 && ssh bestia; }
#}

# Keep this at the end
# Allow different environment scripts to run
#local_scripts=`ls ~/.env-* 2>/dev/null`
#if [ ! -z "$local_scripts" ]; then
#  for f in ~/.env-*; do source $f; done
#fi

if [ -f "/google/devshell/bashrc.google" ]; then
  source "/google/devshell/bashrc.google"
fi

# Mount point, rw access for all users
export MNTDIR="/run/media"

# Only my user has access
export RUNDIR="/run/user/$UID"

## ---- LUKS

# $1=mountpount $2=label
my-luks-mount() {
  P="$2"
  [ -z "$P" ] && P="$1"
  eval "mnt-$1()    { mountpoint -q $MNTDIR/$1 || { mkdir -p $MNTDIR/$1 && sudo cryptsetup open /dev/disk/by-partlabel/$P $1; sudo mount /dev/mapper/$1 $MNTDIR/$1 -o user,noexec,nodev,nosuid,noatime; } }"
  eval "mnt-$1_ro() { mountpoint -q $MNTDIR/$1 || { mkdir -p $MNTDIR/$1 && sudo cryptsetup open /dev/disk/by-partlabel/$P $1; sudo mount /dev/mapper/$1 $MNTDIR/$1 -o ro,user,noexec,nodev,nosuid,noatime; } }"
  eval "umnt-$1()   { sudo umount /dev/mapper/$1; sleep 2; sudo cryptsetup close $1; }"
  eval "go-$1()     { cd $MNTDIR/$1; }"
  export -f "mnt-$1"
  export -f "mnt-$1_ro"
  export -f "umnt-$1"
  export -f "go-$1"
}

# Mount luks encrypted partitions by label

# Always online drives
my-luks-mount backup_bestia

# Manual swtich drives
my-luks-mount backup_bestia_aged
my-luks-mount backup_archive_media
my-luks-mount backup_archive_ice
my-luks-mount backup_borg

# Online only on-request drives (by controlling the usb relay)
my-luks-mount archive_media
my-luks-mount archive_ice
my-luks-mount borg

## -- NO-LUKS

# $1=mountpount $2=label $3=mntoptions
my-mount() {
  P="$2"
  [ -z "$P" ] && P="$1"
  # by-partlabel has priority over by-label
  eval "mnt-$1()    { mountpoint -q $MNTDIR/$1 || { mkdir -p $MNTDIR/$1 && if [ -L /dev/disk/by-partlabel/$P ]; then sudo mount /dev/disk/by-partlabel/$P $MNTDIR/$1 -o rw,$3; return 0; fi && if [ -L /dev/disk/by-label/$P ]; then sudo mount /dev/disk/by-label/$P $MNTDIR/$1 -o rw,$3; return 0; fi; } }"
  eval "mnt-$1_ro() { mountpoint -q $MNTDIR/$1 || { mkdir -p $MNTDIR/$1 && if [ -L /dev/disk/by-partlabel/$P ]; then sudo mount /dev/disk/by-partlabel/$P $MNTDIR/$1 -o rw,$3; return 0; fi && if [ -L /dev/disk/by-label/$P ]; then sudo mount /dev/disk/by-label/$P $MNTDIR/$1 -o ro,$3; return 0; fi; } }"
  eval "umnt-$1()   { sudo umount $MNTDIR/$1 ; }"
  eval "go-$1()     { cd $MNTDIR/$1; }"
  export -f "mnt-$1"
  export -f "mnt-$1_ro"
  export -f "umnt-$1"
  export -f "go-$1"
}

my-mount linux
my-mount linux_bestia
my-mount linux_live
my-mount home_transient
my-mount home_bestia

my-mount efi EFI "user,uid=$(id -u),gid=$(id -g),fmask=0177,dmask=0077,noexec,nosuid,nodev"
my-mount efi_bestia EFI_BESTIA "user,uid=$(id -u),gid=$(id -g),fmask=0177,dmask=0077,noexec,nosuid,nodev"
my-mount efi_live EFI_LIVE "user,uid=$(id -u),gid=$(id -g),fmask=0177,dmask=0077,noexec,nosuid,nodev"

export -f mnt-linux
export -f umnt-linux

## SPEACIAL

alias mnt-backup_pancel='sudo cryptsetup open --type tcrypt --veracrypt --verbose /dev/disk/by-partlabel/backup_pancel backup_pancel && mkdir -p /tmp/hfspluspancel && sudo mount /dev/mapper/backup_pancel /tmp/hfspluspancel -o rw,noexec,nosuid,nodev && mkdir -p $MNTDIR/backup_pancel && sudo bindfs -u $(id -u) -g $(id -g) -o rw /tmp/hfspluspancel $MNTDIR/backup_pancel'
alias umnt-backup_pancel='sudo umount $MNTDIR/backup_pancel /tmp/hfspluspancel; sudo cryptsetup close backup_pancel;'

mnt-archive_bagoly()    { mountpoint -q $MNTDIR/archive_bagoly || { mkdir -p $MNTDIR/archive_bagoly && sudo cryptsetup open /home/archive_bagoly/archive_bagoly.img archive_bagoly && sudo mount /dev/mapper/archive_bagoly $MNTDIR/archive_bagoly -o user,user_xattr,noexec,nosuid,nodev,noatime; } }
mnt-archive_bagoly_ro() { mountpoint -q $MNTDIR/archive_bagoly || { mkdir -p $MNTDIR/archive_bagoly && sudo cryptsetup open /home/archive_bagoly/archive_bagoly.img archive_bagoly && sudo mount /dev/mapper/archive_bagoly $MNTDIR/archive_bagoly -o ro,user,user_xattr,noexec,nosuid,nodev,noatime; } }
umnt-archive_bagoly()   { sudo umount $MNTDIR/archive_bagoly; sudo cryptsetup close archive_bagoly; }

# Online only on-request drives (by controlling the usb relay)
function mnt-relay() {
  relay_on
  mnt-archive_media
  mnt-archive_ice
  mnt-borg
}

function mnt-all_partitions() {
  # Always online drives
  mnt-home_bestia
  mnt-backup_bestia
  mnt_linux
  mnt-linux_bestia
  mnt-efi
  mnt-efi_bestia

  # Manual switch drives and manual backup
  mnt-backup_archive_media
  mnt-backup_archive_ice
  mnt-backup_borg
  mnt-backup_bestia_aged
  mnt-backup_archive_media_aged
  mnt-backup_archive_ice_aged

  # Online only on-request drives (by controlling the usb relay)
  mnt-relay

  # Special
  mnt-backup_pancel
}

function umnt-all() {
  sudo umount $MNTDIR/*
}

export BORG_CACHE_DIR=$MNTDIR/borg/.cache-borg/borg
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

export MEDIA_DB_DIR=$MNTDIR/archive_media/archive_media/meta/db

borg-archive_media()  { cd $MNTDIR/archive_media && nohup borg create --noatime --nobsdflags --compression none -s -x --list $MNTDIR/borg/borg/archive_media::archive_media-`date -Iseconds` archive_media >/tmp/nohup-borg-archive_media.out 2>&1; }

borg-archive_media_image()  { cd $MNTDIR/archive_media && nohup borg create --noatime --nobsdflags --compression none --exclude-from ~/.dotfiles/doc/videoextensions-exclude -s -x --list $MNTDIR/borg/borg/archive_media::archive_media_image-`date -Iseconds` archive_media/p/o >/tmp/nohup-borg-archive_media_image.out 2>&1; }
borg-archive_media_video()  { cd $MNTDIR/archive_media && nohup borg create --noatime --nobsdflags --compression none --patterns-from ~/.dotfiles/doc/videoextensions -s -x --list $MNTDIR/borg/borg/archive_media::archive_media_video-`date -Iseconds` archive_media/p/o >/tmp/nohup-borg-archive_media_video.out 2>&1; }

borg-archive_ice()    { cd $MNTDIR/archive_ice && nohup borg create --noatime --nobsdflags -s -x --list $MNTDIR/borg/borg/archive_ice::archive_ice-`date -Iseconds` archive >/tmp/nohup-borg-archive_ice.out 2>&1; }
borg-archive_bagoly() { cd $MNTDIR/archive_bagoly && nohup borg create --noatime -s --nobsdflags -x --list $MNTDIR/borg/borg/data::data-`date -Iseconds` . >/tmp/nohup-borg-archive_bagoly.out 2>&1; }
borg-bagoly()         { cd $MNTDIR/bagoly && nohup borg create --noatime --nobsdflags -s -x --list $MNTDIR/borg/borg/data::bagoly-`date -Iseconds` . >/tmp/nohup-borg-bagoly.out 2>&1; }
borg-bestia()    { cd $MNTDIR/mail && nohup borg create --noatime --nobsdflags -s -x --list $MNTDIR/borg/borg/mail::mail-`date -Iseconds` . >/tmp/nohup-borg-mail.out 2>&1; }

borg-archive_media_longterm()  { cd $MNTDIR/archive_media && nohup borg create --noatime --nobsdflags -s -x --list $MNTDIR/backup_borg/borg/repo::backup_archive_media-`date -Iseconds` archive_media >/tmp/nohup-borg-backup_archive_media.out 2>&1; }
borg-archive_ice_longterm()    { cd $MNTDIR/archive_ice && nohup borg create --noatime --nobsdflags -s -x --list $MNTDIR/backup_borg/borg/repo::longterm_archive_ice-`date -Iseconds` archive >/tmp/nohup-borg-longterm_archive_ice.out 2>&1; }

alias mnt-mac='sshfs -o allow_other -o Ciphers=aes128-ctr -o Compression=no mac:/ $MNTDIR/mac'
alias mnt-mac-wired='sshfs -o allow_other -o Ciphers=aes128-ctr -o Compression=no mac_wired:/ $MNTDIR/mac'
alias umnt-mac='sudo umount /mnt/mac'

alias mnt-mac-bestia='mkdir -p ~/bestia; sshfs -o Ciphers=aes128-ctr -o Compression=no bestia:/ ~/bestia'
alias umnt-mac-bestia='sudo diskutil unmount force ~/bestia'

alias mnt-0='mkdir -p ~/.disk0 && mount ~/.disk0 && sudo cryptsetup open --type tcrypt ~/.disk0/0 0 && mkdir -p ~/0 && sudo mount /dev/mapper/0 ~/0 -o user,uid=$(id -u),gid=$(id -g),fmask=0177,dmask=0077,noexec,nosuid,nodev'
alias umnt-0='sudo umount ~/0 && sudo cryptsetup close 0 && sudo umount ~/.disk0 && rmdir ~/0 && rmdir ~/.disk0'

borg-archive_media_image_pancel()  { cd $MNTDIR/archive_media/archive_media/p/o && nohup borg create --noatime --nobsdflags --compression none --exclude-from ~/.dotfiles/doc/videoextensions-exclude -s -x --list $MNTDIR/backup_pancel/borg::archive_media_image-`date -Iseconds` . >/tmp/nohup-borg-archive_media_image_pancel.out 2>&1; }

# Backup to disk-tape
# tape = slow, large and reliable storage
function backup-to-tape() {
  # Stop autosuspend
  # Todo - reenable autosuspend after backup finished
  sudo systemctl stop autosuspend.service

  # Umount container files, so that we can properly snapshot for backup
  if ! [[ $(findmnt -Pn /run/media/archive_bagoly | grep OPTIONS=\"ro,) ]]; then
     umnt-archive_bagoly
  fi

  if ! [[ $(findmnt -Pn /run/media/bagoly | grep OPTIONS=\"ro,) ]]; then
     umnt-bagoly
  fi

  # Mount destinations
  mnt-borg

  # Mount data to backup ro
  mnt-archive_ice_ro
  mnt-archive_media_ro
  mnt-archive_bagoly_ro
  mnt-bagoly_ro

  # Backup to 3 borg repositories in paralell
  # HDD

  if mountpoint -q $MNTDIR/archive_ice/ ; then
    echo 1
    borg-archive_ice &
  fi

  if mountpoint -q $MNTDIR/archive_media/ ; then
    echo 2
    borg-archive_media &
  fi

  {
    # backing up to the same borg repo, so needs to be sequential

    if mountpoint -q $MNTDIR/archive_bagoly/ ; then
      borg-archive_bagoly
    fi

    if mountpoint -q $MNTDIR/bagoly/ ; then
      borg-bagoly
    fi
  } &
}

function backup-bestia() {
  # Attempt to mount every partitions
  mnt-all_partitions

  # if source and destinations are available, run the backup

  if mountpoint -q $MNTDIR/home_bestia/ ; then
    sudo rsync -a --progress --delete-after --exclude '*.vmsd' /home/ $MNTDIR/home_bestia/

    # Backup cloud locally
    sync_from_cloud.sh
  fi

  if mountpoint -q $MNTDIR/backup_archive_media/ ; then
    nohup rsync -a --progress --delete-after $MNTDIR/archive_media/archive_media/ $MNTDIR/backup_archive_media/ &
  fi

  if mountpoint -q $MNTDIR/backup_archive_ice/ ; then
    nohup rsync -a --progress --delete-after $MNTDIR/archive_ice/archive $MNTDIR/backup_archive_ice/ &
  fi

  if mountpoint -q $MNTDIR/backup_pancel/ ; then
    borg-archive_media_image_pancel
  fi

  backup-to-tape

  if mountpoint -q $MNTDIR/efi_bestia/ ; then
    rsync -a --delete $MNTDIR/efi/ $MNTDIR/efi_bestia/
  fi

  if mountpoint -q $MNTDIR/linux_bestia/ ; then
    rw $MNTDIR/linux_bestia/
    sudo rm -rf $MNTDIR/linux_bestia/linux
    sudo btrfs send $MNTDIR/linux/linux/ | sudo btrfs receive $MNTDIR/linux_bestia/
  fi
}

alias mnt-1="sshfs bestia:$MNTDIR/data ~/1"
alias umnt-1="sudo umount ~/1"
alias lsb="lsblk -o name,partlabel,label,mountpoint,fstype,size,fsavail,fsuse%,uuid"

function eject () {
  sudo udisksctl  power-off -b /dev/$1
}

alias backup-melo="rsync -av --delete-after --exclude '.vm' /Users/adat/ bestia:/run/media/backup_bestia/melo"
alias backup-taska="umnt-bagoly 2>/dev/null;  rsync -av /Volumes/shared/bagoly bestia:/home/adat/.bagoly ; rsync -av --delete-after --exclude '.Trashes' --exclude '.fseventsd' --exclude '.Spotlight-V100' --exclude '.TemporaryItems' --exclude 'Caches' --exclude '.DocumentRevisions-V100' /Volumes/data /Volumes/shared  bestia:/run/media/backup_bestia/taska"

# TODO - write a generic backup functiona that discovers on which machine it runs and it acts accordingly

if [ -e /home/user/.nix-profile/etc/profile.d/nix.sh ]; then . /home/user/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

alias python=python3

go-d() { cd ~/.dotfiles; }

boot-console() { mnt-efi && echo "set default=console" >  /go/efi/config/grub-onetime.cfg; }


# key binding to exit the shell (on an empty line) - ctrl+q instead of ctrl+d
stty eof \^q

# key binding to interrupt execution or empty the line
stty intr \^d

#I typically use stty -ixon -ixoff so I can reclaim the CTRL-S and CTRL-Q key bindings for more modern purposes
stty -ixon -ixoff
