#!/bin/sh

# todo - fixme - new branch and moved back to github
#git -C /run/media/backup_bestia/gitlab/dotfiles.clone pull
#git -C /run/media/backup_bestia/gitlab/dotfiles.clone gc

rclone sync --exclude Henrik_MeadowBrook/**  --exclude Henrik/**  gombidrive: ~/.gombidrive
rclone sync --ignore-errors henrikdrive: /run/media/backup_bestia/henrikdrive 2>/dev/null
