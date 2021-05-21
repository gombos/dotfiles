#!/bin/sh

git -C /run/media/backup_bestia/gitlab/dotfiles.clone pull
git -C /run/media/backup_bestia/gitlab/dotfiles.clone gc

rclone sync --exclude Henrik_MeadowBrook/**  --exclude Henrik/**  gombidrive: /run/media/backup_bestia/gombidrive
rclone sync --ignore-errors henrikdrive: /run/media/backup_bestia/henrikdrive 2>/dev/null
