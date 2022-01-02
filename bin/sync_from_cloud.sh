#!/bin/sh

# todo - fixme - new branch and moved back to github
#git -C /run/media/backup_bestia/gitlab/dotfiles.clone pull
#git -C /run/media/backup_bestia/gitlab/dotfiles.clone gc

rclone sync --exclude Henrik_MeadowBrook/** gombidrive: ~/gombidrive
rclone sync --exclude Henrik_MeadowBrook/** henrikdrive: ~/henrikdrive
rclone sync cadrive: ~/cadrive
