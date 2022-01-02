#!/bin/sh

# todo - fixme - new branch and moved back to github
#git -C /run/media/backup_bestia/gitlab/dotfiles.clone pull
#git -C /run/media/backup_bestia/gitlab/dotfiles.clone gc

#todo - instead of commenting out things, better take a comamnd line argument

rclone sync cadrive: ~/cadrive

rclone sync --exclude Henrik_MeadowBrook/** gombidrive: ~/gombidrive

#rclone sync --exclude Henrik_MeadowBrook/** henrikdrive: ~/henrikdrive

