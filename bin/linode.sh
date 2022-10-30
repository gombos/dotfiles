#!/bin/bash

set -x

# Takes about 4 min to bring up a linode instance with my ISO
# - create linode and boot into host debian os (1 min)
# - download iso from github - see infra.sh (1 min)
# - shut down (1 min) - can this be done faster ?
# - boot into new iso (1 min)

[ -z "$LABEL" ] && LABEL="pincer"

# debian11 (0.9GB) ubuntu21.10 (2.1GB) alpine3.15 (0.2 GB) centos-stream9 (1.2 GB) arch (2.1GB)
# linode-cli images list
[ -z "$DISTRO" ] && DISTRO="debian11"

# todo - remove path
Key=$(cat /Volumes/bagoly/k.git/k_public)
MY_SERVER_AUTORIZED_KEY="$Key"
LOG=$(cat /Volumes/bagoly/homelab.git/log.txt)

# rebuild will NOT change IP.. yay
firewallId=$(linode-cli firewalls list --text --no-headers --format id)

# Use linode infra to manage open ports
port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq -r '{ ports: .ports, label: .label } | select(.label=="accept-inbound-SSH").ports')

stackscript_id=$(linode-cli stackscripts list --label infra --text --no-headers --format id)

# Needs to be both a valid JSON value and valid shell script
BOOTSCRIPT="SSHD_PORT=$port \
  LABEL=$LABEL \
  USR=usr \
  LOG=\\\"$LOG\\\" "

linodeId=$(linode-cli linodes list --label $LABEL --text --no-headers --format 'id')

if [ -n "$linodeId" ]; then
  linode-cli linodes rebuild --root_pass --authorized_keys "$MY_SERVER_AUTORIZED_KEY" --image linode/$DISTRO $linodeId \
  --stackscript_id $stackscript_id --stackscript_data "{\"SCRIPT\":\"$BOOTSCRIPT\" }"
else
  linode-cli linodes create --type g6-nanode-1 --region us-east --label $LABEL --booted true --backups_enabled false --root_pass --authorized_keys "$MY_SERVER_AUTORIZED_KEY" --image linode/$DISTRO
fi

# copy over k
#scp -o "StrictHostKeyChecking no" -r /Volumes/bagoly/homelab.git/boot/* l:

# Reregisters IP if IP changed - assumes one linode, one domain and one A record
#ip=$(linode-cli linodes list --label $LABEL --text --no-headers --format 'ipv4')
#domainId=$(linode-cli domains list --text --no-headers --format id)
#recordId=$(linode-cli domains records-list $domainId --text --no-headers --format id)
#linode-cli domains records-update $domainId $recordId --target $ip

#firewallId=$(linode-cli firewalls list --text --no-headers --format id)
#port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq .ports)