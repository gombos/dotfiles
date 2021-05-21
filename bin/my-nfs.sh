#!/bin/bash
if [[ $1 == 'start' ]]; then
        echo "*** Repopulate NFS exports ..."
        sudo rm -rf /etc/exports

        echo "/home/upload/   192.168.1.0/24(rw,sync,insecure,no_subtree_check)" | sudo tee -a /etc/exports > /dev/null

        [ "$(ls -A $MNTDIR/archive_media)" ] && echo "/run/media/archive_media/archive_media/ 192.168.1.0/24(ro,sync,insecure,no_subtree_check)" | sudo tee -a /etc/exports > /dev/null

        echo "*** starting nfs services..."
        sudo systemctl start nfs-server | grep failed
        sudo systemctl start rpc-statd | grep failed

elif [[ $1 == 'stop' ]]; then
        echo "*** stopping nfs services..."
        sudo systemctl stop rpc-statd | grep failed
        sudo systemctl stop nfs-server | grep failed
else
        echo "*** No valid options given. Please re-run with either 'start' or 'stop'."
fi
