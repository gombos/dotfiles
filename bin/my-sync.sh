#!/bin/sh
#--prune-empty-dirs

rsync --archive --acls --xattrs --times --human-readable --verbose "$@"
