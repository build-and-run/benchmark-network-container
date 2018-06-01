# Container Network Benchmark Protocol

[TOC]

## Goal



## Environment

### Hardware 

The lab is made of 3 Supermicro nodes, each is equipped with :
- cpu : *Intel Xeon E5-1630 v3 (4 cores 8 threads 3.7Ghz)*
- ram : *32Go RAM made of 4 banks of 8 Go DDR4 2133Mhz*
- raid :  *Raid hardware LSI Megaraid 9361-4i with BBU*
- storage : *4 disks 240Go SSD Intel S3500 in RAID 0*
- network : *1 NIC Supermicro Dual port 10Gbit SFP+* 

The lab switch is a *Supermicro SSE-X3348SR 48 ports 10Gbit SFP+*

Nodes are connected to switch via 1 meter SFP+ Direct Attach Copper (DAC) cable.

Here is a simple schema of the lab :

```
+----------+  +----------+  +----------+
|Server s02|  |Server s03|  |Server s04|
| 10.1.1.2 |  | 10.1.1.3 |  | 10.1.1.4 |
+----------+  +----------+  +----------+
     |             |              |     
     |DAC          |DAC           |DAC  
     |             |              |     
+--------------------------------------+
|            Switch 10Gbit             |
+--------------------------------------+
```

### Software

#### Operating System 

We will conduct this benchmark with **Ubuntu 18.04** (last LTS at this time). Nodes are deployed via MAAS from Canonical.

Kernel version : `4.15.0-22-generic`

#### Docker

The Docker version we will use is the default one on Ubuntu 18.04, **Docker 17.12.1-ce** : 

```
Client:
 Version:	17.12.1-ce
 API version:	1.35
 Go version:	go1.10.1
 Git commit:	7390fc6
 Built:	Wed Apr 18 01:23:11 2018
 OS/Arch:	linux/amd64

Server:
 Engine:
  Version:	17.12.1-ce
  API version:	1.35 (minimum version 1.12)
  Go version:	go1.10.1
  Git commit:	7390fc6
  Built:	Wed Feb 28 17:46:05 2018
  OS/Arch:	linux/amd64
  Experimental:	false
```

#### Rancher

We will use Rancher **1.6.7** with Cattle environment

Node s04 will act as Rancher Server, s02 and s03 will act as cluster nodes. Schema :

```
+----------+  +----------+  +----------+
|Server s02|  |Server s03|  |Server s04|
|   node   |  |   node   |  |  server  |
+----------+  +----------+  +----------+
     |             |              |     
     |             |              |     
+--------------------------------------+
|            Switch 10Gbit             |
+--------------------------------------+
```



#### Kubernetes

Kubernetes **v1.10.3** setup with **kubeadm** :

```
Server Version: version.Info{Major:"1", Minor:"10", GitVersion:"v1.10.3", GitCommit:"2bba0127d85d5a46ab4b778548be28623b32d0b0", GitTreeState:"clean", BuildDate:"2018-05-21T09:05:37Z", GoVersion:"go1.9.3", Compiler:"gc", Platform:"linux/amd64"}
```

Node s04 will act as master node, **s02** and s03 will act as minion. Schema :

```
+----------+  +----------+  +----------+
|Server s02|  |Server s03|  |Server s04|
|   node   |  |   node   |  |  server  |
+----------+  +----------+  +----------+
     |             |              |     
     |             |              |     
+--------------------------------------+
|            Switch 10Gbit             |
+--------------------------------------+
```

### Benchmark tools

#### TCP benchmark with iperf3

On the server side, we will just launch iperf3 in server mode

```bash
# iperf3 TCP and UDP server
iperf3 -s
```

On the client side, we will launch iperf3 in tcp mode (default), omitting the first bunch of packets (-O 1) to prevent the TCP Slow start and finally connection on the IP of the server (-c 10.1.1.2)

```bash
# iperf3 TCP client command
iperf3 -O 1 -c 10.1.1.2
```

Output sample :

```
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  11.5 GBytes  9.86 Gbits/sec  259             sender
[  5]   0.00-10.04  sec  11.5 GBytes  9.86 Gbits/sec                  receiver

iperf Done.
```

From the output, we will extract the **Bitrate** (9.86 Gbits/sec), and the TCP retransmits "**Retr**" (259).

#### UDP benchmark with iperf3

On the server side, we will reuse the TCP iperf3 server, launched as :

```bash
# iperf3 TCP and UDP server
iperf3 -s
```

On the client side, we will launch iperf3 in udp mode (-u), with unlimited bandwidth (-b 0), using a 2MB buffer (-w 2M), omitting the first bunch of packets (-O 1) and finally connection on the IP of the server (-c 10.1.1.2)

```bash
# iperf3 UDP client command
iperf3 -u -b 0 -O 1 -c 10.1.1.2 -w 256K
```

Output sample :

```
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Jitter    Lost/Total Datagrams
[  4]   0.00-10.00  sec  11.5 GBytes  9.92 Gbits/sec  0.006 ms  112/1513578 (0.0074%)
[  4] Sent 1513578 datagrams

iperf Done.
```

From the output, we will extract the **Bandwidth** (9.92 Gbits/sec), the **Jitter** (0.006 ms) and the **loss percentage** (0.0074%).

#### HTTP benchmark with Nginx and curl

On the server side, we will use a simple **Nginx** with default configuration.

On the client side, the HTTP test command is a simple curl with http:// scheme without authentication :

```Bash
# HTTP client command
curl -o /dev/null http://10.1.1.2/10G.dat
```

Output sample

```bash
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  9.7G  100  9.7G    0     0  1180M      0  0:00:08  0:00:08 --:--:-- 1180M
```

From the output, we will extract only the average download speed "**Average Dload**" (1180M) in MByte/scd

#### FTP benchmark with vsftpd and curl 

On the server side, we will use a simple **vsftpd** with following configuration :

```ini
listen=YES
anonymous_enable=YES
dirmessage_enable=YES
use_localtime=YES
connect_from_port_20=YES
secure_chroot_dir=/var/run/vsftpd/empty
write_enable=NO
seccomp_sandbox=NO
xferlog_std_format=NO
log_ftp_protocol=YES
syslog_enable=YES
hide_ids=YES
seccomp_sandbox=NO
pasv_enable=YES
port_enable=YES
anon_root=/var/ftp
pasv_max_port=65515
pasv_min_port=65500
max_per_ip=2
max_login_fails=2
max_clients=50
anon_max_rate=0
ftpd_banner=Welcome to an awesome public FTP Server
banner_file=
pasv_address=
```

On the client side, the FTP test command is a simple curl request with ftp:// scheme in anonymous mode :

```bash
# FTP client command
curl -o /dev/null ftp://10.1.1.2/10G.dat
```

Output sample :

```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  9.7G  100  9.7G    0     0  1173M      0  0:00:08  0:00:08 --:--:-- 1180M
```

From the output, we will extract only the average download speed "**Average Dload**" (1173M) in MByte/s

#### SCP benchmark with OpenSSH server and client

On the server side, we will default OpenSSH server shipped with Ubuntu 18.04.

On the client side, the SCP test command is a simple openssh download using scp :

```bash
# SCP client command
scp 10.1.1.2:/home/ubuntu/10G.dat ./
```

output sample :

```
10G.dat                            100%   10GB 267.9MB/s   00:37
```

From the output, we will extract the **bandwidth** (267.9MB/s)

## Benchmark protocol

For each scenario, we will redeploy a fresh Ubuntu 18.04 on each nodes. We just change the MTU of the NIC to 9000, and the DNS nameserver to set Google's one (8.8.8.8).

Post-deploy setup script :

```bash
sudo sed -i 's/mtu: 1500/mtu: 9000/' /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo sed -i 's/nameserver .*/nameserver 8.8.8.8/' /etc/resolv.conf
```

Benchmark server part will always be bound to node s02, and benchmark client part will always be bound to node s03. The node s04 is only used to act as master node for Kubernetes and Docker.

HTTP, FTP and SSH benchmarks assets are based on a 10G file transfer, to improve reproducibility we will generate the dumb file one time, and reuse it for each scenario. This 10GB dumb file has been generated with `dd` using `/dev/urandom` to prevent any compression bias during transfer.

Sequence diagram :

```
      deploy fresh 3 nodes    
              |
              v
 prepare nodes (dns/mtu/assets)
              |
              v
     [option] setup docker    
              |               
              v               
 [option] setup Rancher or K8S
              |               
              v               
    run benchmark iperf3 TCP  
              |               
              v               
    run benchmark iperf3 UDP  
              |               
              v               
      run benchmark HTTP      
              |               
              v               
       run benchmark FTP      
              |               
              v               
       run benchmark SSH      
              |               
              v               
       drop all 3 nodes
```



## Test grid

Here are the differents 

## Docker Standalone



## Docker Swarm

### Preparing cluster

Initializing master :

```bash
docker swarm init --advertise-addr 10.1.1.4
```





## Kubernetes 

### Preparing Cluster

On Ubuntu 18.04, nodes 

```bash
for i in 2 3 4; do lssh $i "sudo sed -i 's/mtu: 1500/mtu: 9000/' /etc/netplan/50-cloud-init.yaml && sudo netplan apply; sudo sed -i 's/nameserver .*/nameserver 8.8.8.8/' /etc/resolv.conf"; done

BINONLY=yes ./autokube-multi.sh ubuntu 10.1.1.4 10.1.1.2 10.1.1.3

# kubeadm init ...

lssh 4 "sudo cp /etc/kubernetes/admin.conf ./ && sudo chmod +r admin.conf"
qscp ubuntu@10.1.1.4:/home/ubuntu/admin.conf config
lssh 2 wget http://10.1.1.101/10G.dat

# Choose network

# bench
```



### Setup of network overlays

```bash
# Calico with MTU 1500
# Note : Calico lacks of auto MTU configuration , for jumbo frames (mtu 9000) see next config
    kubeadm init --pod-network-cidr=192.168.0.0/16
    kubectl apply -f kubernetes/network-calico.yaml
    
# Calico with MTU 9000
    kubeadm init --pod-network-cidr=192.168.0.0/16
    kubectl apply -f kubernetes/network-calico-mtu9000.yaml

# Canal
	kubeadm init --pod-network-cidr=10.244.0.0/16
	kubectl apply -f kubernetes/network-canal.yml

# Flannel
    kubeadm init --pod-network-cidr=10.244.0.0/16
    kubectl apply -f kubernetes/network-flannel.yaml
    
# Romana
	kubeadm init
	kubectl apply -f kubernetes/network-romana.yaml
    
# Kube-Router
	kubeadm init --pod-network-cidr=10.244.0.0/16
	kubectl apply -f kubernetes/network-kuberouter.yaml

# Weave Net
# Note : Weave Net lacks of auto MTU configuration , for jumbo frames (mtu 9000) see next config
	kubeadm init
	kubectl apply -f kubernetes/network-weavenet.yml
	
# Weave Net with MTU 8912
	kubeadm init
	kubectl apply -f kubernetes/network-weavenet-mtu8912.yml
```


### Benchmark commands

#### Testing TCP and UDP with iperf3

```bash
# Creating HTTP Server Pod
kubectl apply -f kubernetes/server-iperf3.yml

# Waiting for pod to be alive
while true; do kubectl get pod|grep iperf-srv |grep Running && break; sleep 1; done

# Retrieving Pod IP address
IP=$(kubectl get pod/iperf-srv -o jsonpath='{.status.podIP}')
echo Server iperf3 is listening on $IP

# Launching benchmark for TCP
kubectl run --restart=Never -it --rm bench --image=infrabuilder/netbench:client --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- iperf3 -c $IP -O 1 

# Launching benchmark for UDP
kubectl run --restart=Never -it --rm bench --image=infrabuilder/netbench:client --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- iperf3 -u -b 0 -c $IP -O 1 -w 256K

# Cleaning
kubectl delete -f kubernetes/server-iperf3.yml
```

#### Testing HTTP

```bash
# Creating HTTP Server Pod
kubectl apply -f kubernetes/server-http.yml

# Waiting for pod to be alive
while true; do kubectl get pod|grep http-srv |grep Running && break; sleep 1; done

# Retrieving Pod IP address
IP=$(kubectl get pod/http-srv -o jsonpath='{.status.podIP}')
echo Server HTTP is listening on $IP

# Launching benchmark
kubectl run --restart=Never -it --rm bench --image=infrabuilder/netbench:client --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- curl -o /dev/null http://$IP/10G.dat 

# Cleaning
kubectl delete -f kubernetes/server-http.yml
```

#### Testing FTP

```bash
# Creating FTP Server Pod
kubectl apply -f kubernetes/server-ftp.yml

# Waiting for pod to be alive
while true; do kubectl get pod|grep ftp-srv |grep Running && break; sleep 1; done

# Retrieving Pod IP address
IP=$(kubectl get pod/ftp-srv -o jsonpath='{.status.podIP}')
echo Server FTP is listening on $IP

# Launching benchmark
kubectl run --restart=Never -it --rm bench --image=infrabuilder/netbench:client --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- curl -o /dev/null ftp://$IP/10G.dat

# Cleaning
kubectl delete -f kubernetes/server-ftp.yml
```

#### Testing SCP

```bash
# Creating SSH Server Pod
kubectl apply -f kubernetes/server-ssh.yml

# Waiting for pod to be alive
while true; do kubectl get pod|grep ssh-srv |grep Running && break; sleep 1; done

# Retrieving Pod IP address
IP=$(kubectl get pod/ssh-srv -o jsonpath='{.status.podIP}')
echo Server SSH is listening on $IP

# Launching benchmark (must enter "yes" and password "root" manually)
kubectl run --restart=Never -it --rm bench --image=infrabuilder/netbench:client --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- scp root@$IP:/root/10G.dat ./

# Cleaning
kubectl delete -f kubernetes/server-ssh.yml
```

## Authors

This benchmark has been conducted by **Build and Run**, a French devops freelance group. 

The protocol has been designed by **Alexis Ducastel**, **Ivan Beauté**, and **Frédéric Léger**.

At the moment, the **Build and Run** group is composed of :

- **Ivan Beauté** from **Fabrique IT**
- **Alexis Ducastel** from **infraBuilder**
- **Denis Garcia** from **Kiadra**
- **Julie Kolarovic** from **Sainen**
- **Frédéric Léger** from **webofmars**
- **Rénald Koch** 