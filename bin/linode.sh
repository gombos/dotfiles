#!/bin/bash

set -x

# Takes about 4 min to bring up a linode instance with my ISO
# - create linode and boot into host debian os (1 min)
# - download iso from github - see infra.sh (1 min)
# - shut down (1 min) - can this be done faster ?
# - boot into new iso (1 min)

#Rebuild feature performs the following two actions:
# - The current disks are removed.
# - A new set of disks is provisioned from one of the Cloud Manager’s built-in Linux images, or from one of the saved images.

[ -z "$LABEL" ] && LABEL="pincer"

# debian (1 GB) ubuntu (2 GB) arch (2GB) alpine (0.2GB)
# linode-cli images list
[ -z "$DISTRO" ] && DISTRO="debian12"

# todo - remove path
Key=$(cat /Volumes/bagoly/k.git/k_public)
MY_SERVER_AUTORIZED_KEY="$Key"
LOG=$(cat /Volumes/bagoly/homelab.git/log.txt)
TS=$(cat /Volumes/bagoly/k.git/ts-pincer)
port=$(cat /Volumes/bagoly/k.git/port)
SSHD_KEY=$(cat /Volumes/bagoly/k.git/sshdkey)
SSHD_KEY_PUB='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEcfrj/nT5WjUf9atsVxK6wT0QJsMh2vmyveF7NC9sIV root@localhost'

# rebuild will NOT change IP.. yay
firewallId=$(linode-cli firewalls list --text --no-headers --format id)

# Use linode infra to manage open ports
#port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq -r '{ ports: .ports, label: .label } | select(.label=="accept-inbound-SSH").ports')

stackscript_id=$(linode-cli stackscripts list --label infra --text --no-headers --format id)

# Needs to be both a valid JSON value and valid shell script
BOOTSCRIPT="SSHD_PORT=$port \
  LABEL=$LABEL \
  USR=usr \
  TS=\\\"$TS\\\" \
  SSHD_KEY=\\\"$SSHD_KEY\\\" \
  SSHD_KEY_PUB=\\\"$SSHD_KEY_PUB\\\" \
  LOG=\\\"$LOG\\\" "

linodeId=$(linode-cli linodes list --label $LABEL --text --no-headers --format 'id')

# pincer │ us-east │ g6-nanode-1 │ linode/debian12

if [ -n "$linodeId" ]; then
  linode-cli linodes rebuild --root_pass --authorized_keys "$MY_SERVER_AUTORIZED_KEY" --image linode/$DISTRO $linodeId \
  --stackscript_id $stackscript_id --stackscript_data "{\"SCRIPT\":\"$BOOTSCRIPT\" }"
fi

# linode-cli linodes create --type g6-nanode-1 --region us-east --label $LABEL --booted true --backups_enabled false --root_pass --authorized_keys "$MY_SERVER_AUTORIZED_KEY" --image linode/$DISTRO

# copy over k
#scp -o "StrictHostKeyChecking no" -r /Volumes/bagoly/homelab.git/boot/* l:

# Reregisters IP if IP changed - assumes one linode, one domain and one A record
#ip=$(linode-cli linodes list --label $LABEL --text --no-headers --format 'ipv4')
#domainId=$(linode-cli domains list --text --no-headers --format id)
#recordId=$(linode-cli domains records-list $domainId --text --no-headers --format id)
#linode-cli domains records-update $domainId $recordId --target $ip

#firewallId=$(linode-cli firewalls list --text --no-headers --format id)
#port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq .ports)