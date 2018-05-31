#!/bin/bash
sudo sed -i 's/mtu: 1500/mtu: 9000/' /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo sed -i 's/nameserver .*/nameserver 8.8.8.8/' /etc/resolv.conf
