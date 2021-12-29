#!/bin/bash

echo "$1 192.168.1.0/28(ro,sync,wdelay,hide,nocrossmnt,insecure,root_squash,no_all_squash,no_subtree_check,secure_locks,acl,no_pnfs,anonuid=65534,anongid=65534,sec=sys)" | sudo tee -a /var/lib/nfs/etab
echo "$1 192.168.1.0/28(ro,sync,wdelay,hide,nocrossmnt,insecure,root_squash,no_all_squash,no_subtree_check,secure_locks,acl,no_pnfs,anonuid=65534,anongid=65534,sec=sys)" | sudo tee -a /etc/exports

sudo systemctl restart nfs-server
