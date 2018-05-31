# Benchmarking network solutions

## Environment

### Hardware 

The lab is made of 3 Supermicro nodes, each is equipped with :
- cpu : Intel Xeon E5-1630 v3 (4 cores 8 threads 3.7Ghz)
- ram : 32Go RAM : 4 * 8 Go DDR 4 2133Mhz 
- raid :  Raid hardware LSI Megaraid 9361-4i
- storage : 4 * 240Go SSD Intel S3500 in RAID 0
- network : 1 NIC Supermicro Dual port 10Gbit SFP+

The lab switch is a **Supermicro SSE-X3348SR 48 ports 10Gbit SFP+**

Nodes are connected to switch via 1 meter SFP+ Direct Attach Copper (DAC) cable.

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

We will conduct this benchmark with Ubuntu 18.04 (last LTS at this time)

Kernel version : `4.15.0-22-generic`

#### Docker

The Docker version we will use is the default one on Ubuntu 18.04 : 

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

#### Kubernetes

Kubernetes **v1.10.3** setup with **kubeadm**, node s04 will act as master node, s02 and s03 will act as minion.

```
Server Version: version.Info{Major:"1", Minor:"10", GitVersion:"v1.10.3", GitCommit:"2bba0127d85d5a46ab4b778548be28623b32d0b0", GitTreeState:"clean", BuildDate:"2018-05-21T09:05:37Z", GoVersion:"go1.9.3", Compiler:"gc", Platform:"linux/amd64"}
```

### Benchmark tools

#### TCP benchmark with iperf3

We will launch iperf3 in tcp mode (default), omitting the first bunch of packets (-O 1) to prevent the TCP Slow start and finally connection on the IP of the server (-c 10.1.1.2)

```bash
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

We will launch iperf3 in udp mode (-u), with unlimited bandwidth (-b 0), using a 2MB buffer (-w 2M), omitting the first bunch of packets (-O 1) and finally connection on the IP of the server (-c 10.1.1.2)

```Bash
iperf3 -u -b 0 -w 2M -O 1 -c 10.1.1.2 
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

The HTTP test command is a simple curl using HTTP request against a Nginx server without authentication.

```Bash
curl -o /dev/null http://10.1.1.2/10G.dat
```

Output sample

```bash
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  9.7G  100  9.7G    0     0  1180M      0  0:00:08  0:00:08 --:--:-- 1180M
```

From the output, we will extract only the average download speed "**Avergage Dload**" (1180M) in MByte/scd

#### FTP benchmark with 

The FTP test command is a simple curl using FTP request against a VSFTPD server in anonymous mode.

```bash
curl -o /dev/null ftp://10.1.1.2/10G.dat
```

Output sample :

```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  9.7G  100  9.7G    0     0  1173M      0  0:00:08  0:00:08 --:--:-- 1180M
```

From the output, we will extract only the average download speed "**Avergage Dload**" (1173M) in MByte/s

#### Test SCP

The SCP test command is a simple openssh download using scp against a OpenSSH server. 

```Bash
scp 10.1.1.2:/home/ubuntu/10G.dat ./
```

output sample :

```
10G.dat                            100%   10GB 267.9MB/s   00:37
```

From the output, we will extract the **bandwidth** (267.9MB/s)

## Kubernetes 

### Preparing Cluster

```bash
16.04 mtu
	lssh 2 "sudo sed -i 's/mtu 1500/mtu 9000/g' /etc/network/interfaces.d/50-cloud-init.cfg && sudo service networking restart"

18.04 mtu & dns
	for i in 2 3 4; do lssh $i "sudo sed -i 's/mtu: 1500/mtu: 9000/' /etc/netplan/50-cloud-init.yaml && sudo netplan apply; sudo sed -i 's/nameserver .*/nameserver 8.8.8.8/' /etc/resolv.conf"; done

BINONLY=yes ./autokube-multi.sh ubuntu 10.1.1.4 10.1.1.2 10.1.1.3

# Network 
lssh 4 sudo kubeadm init ...

lssh 4 "sudo cp /etc/kubernetes/admin.conf ./ && sudo chmod +r admin.conf"
qscp ubuntu@10.1.1.4:/home/ubuntu/admin.conf config
lssh 2 wget http://10.1.1.101/10G.dat
```



### Setup of network overlays :

```bash
# Calico with MTU 1500
# Note : Calico lacks of auto MTU configuration , for jumbo frames (mtu 9000) see next config
    kubeadm init --pod-network-cidr=192.168.0.0/16
    kubectl apply -f kubernetes/network-calico.yaml
    
# Calico with MTU 9000
    kubeadm init --pod-network-cidr=192.168.0.0/16
    kubectl apply -f kubernetes/network-calico-mtu9000.yaml

# Flannel
    kubeadm init --pod-network-cidr=10.244.0.0/16
    kubectl apply -f kubernetes/network-flannel.yaml
```


### Benchmark commands

#### Test iperf3 :

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
kubectl run --restart=Never -it --rm bench --image=infrabuilder/netbench:client --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- iperf3 -u -b 0 -c $IP -O 1

# Cleaning
kubectl delete -f kubernetes/server-iperf3.yml
```

#### Test HTTP :

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

#### Test FTP :

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

#### Test SCP :

```bash
# Creating SSH Server Pod
kubectl apply -f kubernetes/server-ssh.yml

# Waiting for pod to be alive
while true; do kubectl get pod|grep ssh-srv |grep Running && break; sleep 1; done

# Retrieving Pod IP address
IP=$(kubectl get pod/ssh-srv -o jsonpath='{.status.podIP}')
echo Server SSH is listening on $IP

# Launching benchmark
kubectl run --restart=Never -it --rm bench --image=infrabuilder/netbench:client --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- scp root@$IP:/root/10G.dat ./

# Cleaning
kubectl delete -f kubernetes/server-ssh.yml

scp -o 'Ciphers chacha20-poly1305@openssh.com' root@10.244.1.8:/root/10G.dat ./
scp -o 'Ciphers aes128-str' root@10.244.1.8:/root/10G.dat ./
scp -o 'Ciphers aes256-str' root@10.244.1.8:/root/10G.dat ./
```

VSFTPD config :

```
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

