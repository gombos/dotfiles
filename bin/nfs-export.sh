#!/bin/bash

echo "$1 192.168.1.0/24(rw,sync,wdelay,hide,nocrossmnt,insecure,root_squash,all_squash,no_subtree_check,secure_locks,acl,no_pnfs,anonuid=1000,anongid=1000,sec=sys)" | sudo tee -a /var/lib/nfs/etab
echo "$1 192.168.1.0/24(rw,sync,wdelay,hide,nocrossmnt,insecure,root_squash,all_squash,no_subtree_check,secure_locks,acl,no_pnfs,anonuid=1000,anongid=1000,sec=sys)" | sudo tee -a /etc/exports

sudo systemctl restart nfs-server
