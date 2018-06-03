#!/bin/bash

#cd "$(dirname $0)"

function die { echo $*; exit 1; }
function usage { echo "Usage : $0 username ipnode1 [ipnode2 [ipnode3 [... ]]]"; echo " example : $0 ubuntu 10.1.1.2 10.1.1.3 10.1.1.4"; exit;}
[ "$2" = "" ] && usage

username=$1
shift

SSHCMD="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=QUIET -l $username"
EXTRAPACKAGES="nfs-common"

echo "Checking ssh access"
for ip in $*
do
	[ "$($SSHCMD $ip sudo whoami)" != "root" ] && die "Cannot access to $ip as $username with sudo"
done

echo "Setup binaries"
PIDLIST=""
for ip in $*; do $SSHCMD $ip sudo bash <<EOF &
	[ ! -x /usr/bin/kubeadm ] && (
		apt-get update && apt-get install -y apt-transport-https
		curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
		echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list
		apt-get update
		apt-get install -y docker.io kubelet kubeadm kubectl $EXTRAPACKAGES
	)
	swapoff -a
	sed -i '/\sswap\s/d' /etc/fstab
EOF
PIDLIST="$PIDLIST $!"
done

wait $PIDLIST

echo "Nodes $* prepared for Kubernetes ..."
