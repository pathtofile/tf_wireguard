#!/bin/bash
set -euxo pipefail

# Install WireGuard
sudo apt update
sudo apt install --yes wireguard resolvconf

# Cop config to right location
sudo cp /home/vagrant/wg0.conf /etc/wireguard/wg0.conf
sudo chmod go= /etc/wireguard/wg0.conf

# Start WireGuard client and check it's running as expected
sudo wg-quick up wg0
sudo wg
