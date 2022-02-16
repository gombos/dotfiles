#!/bin/bash

# Takes about 6 min to bring up a linode instance with my ISO
# - configure host debian os
# - download iso
# - boot into new iso
# Most of this time goes into downloading the ISO from github

LABEL="pincer"

# todo - remove path
Key=$(cat /Volumes/bagoly/k.git/k_public)
MY_SERVER_AUTORIZED_KEY="$Key"
LOG=$(cat /Volumes/bagoly/homelab.git/log.txt)

# rebuild will NOT change IP.. yay
firewallId=$(linode-cli firewalls list --text --no-headers --format id)

# Use linode infra to manage open ports
port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq -r '{ ports: .ports, label: .label } | select(.label=="accept-inbound-SSH").ports')

stackscript_id=$(linode-cli stackscripts list --label infra --text --no-headers --format id)

linodeId=$(linode-cli linodes list --label $LABEL --text --no-headers --format 'id')

# Needs to be both a valid JSON value and valid shell script
BOOTSCRIPT="SSHD_PORT=$port \
  LABEL=$LABEL \
  USR=usr \
  LOG=\\\"$LOG\\\" "

linode-cli linodes rebuild --root_pass --stackscript_id $stackscript_id \
  --stackscript_data "{\"SCRIPT\":\"$BOOTSCRIPT\" }" \
  --authorized_keys "$MY_SERVER_AUTORIZED_KEY" --image linode/debian11 $linodeId

#linode/debian11
#linode/ubuntu21.10

# copy over k
#scp -o "StrictHostKeyChecking no" -r /Volumes/bagoly/homelab.git/boot/* l:

# Initial provisioning, will loose IP address
#linode-cli linodes create --type g6-nanode-1 --region us-east --label $LABEL --booted true --backups_enabled false --root_pass --stackscript_id 969974 --authorized_keys  "$MY_SERVER_AUTORIZED_KEY" --image linode/debian11

# Reregisters IP if IP changed - assumes one linode, one domain and one A record
#ip=$(linode-cli linodes list --label $LABEL --text --no-headers --format 'ipv4')
#domainId=$(linode-cli domains list --text --no-headers --format id)
#recordId=$(linode-cli domains records-list $domainId --text --no-headers --format id)
#linode-cli domains records-update $domainId $recordId --target $ip

#firewallId=$(linode-cli firewalls list --text --no-headers --format id)
#port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq .ports)