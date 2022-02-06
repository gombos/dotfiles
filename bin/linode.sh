#!/bin/bash

Key=$( cat /Volumes/bagoly/k.git/k_public )
MY_SERVER_AUTORIZED_KEY="$Key"

# rebuild will NOT change IP.. yay
firewallId=$(linode-cli firewalls list --text --no-headers --format id)

# Use linode infra to manage open ports
#port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq .ports)
port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq '{ ports: .ports, label: .label } | select(.label=="accept-inbound-SSH").ports')

linodeId=$(linode-cli linodes list --label pincer --text --no-headers --format 'id')
linode-cli linodes rebuild --root_pass --stackscript_id 969974 --stackscript_data "{\"SSHDPORT\": $port}" --authorized_keys "$MY_SERVER_AUTORIZED_KEY" --image linode/debian11  $linodeId

# Initial provisioning, will loose IP address
#linode-cli linodes create --type g6-nanode-1 --region us-east --label pincer --booted true --backups_enabled false --root_pass --stackscript_id 969974 --authorized_keys  "$MY_SERVER_AUTORIZED_KEY" --image linode/debian11

# Reregisters IP if IP changed - assumes one linode, one domain and one A record
#ip=$(linode-cli linodes list --label pincer --text --no-headers --format 'ipv4')
#domainId=$(linode-cli domains list --text --no-headers --format id)
#recordId=$(linode-cli domains records-list $domainId --text --no-headers --format id)
#linode-cli domains records-update $domainId $recordId --target $ip

#firewallId=$(linode-cli firewalls list --text --no-headers --format id)
#port=$(linode-cli firewalls rules-list $firewallId --text --no-headers --format inbound | sed 's/'\''/"/g' | jq .ports)