#!/usr/bin/env bash

function get_instance_state () {
  local state=$(aws lightsail get-instance-state --instance-name $1 \
                                                 --query state.name \
                                                 --output text)
  echo $state
}

function wait_for_instance_to_run () {
  local state=$(get_instance_state $1)

  while [ $state != "running" ]
  do
    echo "Waiting for instance $1 to start up..."
    sleep 10

    state=$(get_instance_state $1)
  done
}

aws lightsail delete-instance --instance-name "awslab"
sleep 10

aws lightsail create-instances --instance-names "awslab" --bundle-id "nano_2_0" --blueprint-id "ubuntu_20_04" --availability-zone "us-east-1a" --key-pair-name "k_public" --user-data file://~/.dotfiles/bin/infra-init-final.sh

wait_for_instance_to_run "awslab"

aws lightsail get-instances  | grep publicIpAddress
