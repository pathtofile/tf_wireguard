#!/bin/bash
set -eo pipefail

J=$(terraform output --json)
USERNAME="$(echo $J | jq -r '.username.value')"
IP_ADDRESS="$(echo $J | jq -r '.ip_address.value')"
PORT="$(echo $J | jq -r '.ssh_port.value')"

ssh -o "StrictHostKeyChecking=no" -i "./id_cloud" "$USERNAME@$IP_ADDRESS" -p $PORT
