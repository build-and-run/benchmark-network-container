#!/bin/bash

#cd "$(dirname $0)"

function die { echo $*; exit 1; }
function usage { echo "Usage : $0 username ipnode1 [ipnode2 [ipnode3 [... ]]]"; echo " example : $0 ubuntu 10.1.1.2 10.1.1.3 10.1.1.4"; exit;}
[ "$2" = "" ] && usage

username=$1
shift

SSHCMD="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=QUIET -l $username"

echo "Checking ssh access"
for ip in $*
do
	[ "$($SSHCMD $ip sudo whoami)" != "root" ] && die "Cannot access to $ip as $username with sudo"
done

echo "Preparing nodes"
PIDLIST=""
for ip in $*; do $SSHCMD $ip sudo bash <<EOF &
	sudo sed -i 's/mtu: 1500/mtu: 9000/' /etc/netplan/50-cloud-init.yaml
	sudo netplan apply
	sudo sed -i 's/nameserver .*/nameserver 8.8.8.8/' /etc/resolv.conf
EOF
PIDLIST="$PIDLIST $!"
done

wait $PIDLIST

echo "Nodes $* prepared for benchmark..."
