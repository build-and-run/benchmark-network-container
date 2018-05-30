# Benchmarking network solutions

##  Test protocol

### hardware 

3 nodes :

- cpu : Intel Xeon E5-1630 v3 (4 cores 8 threads 3.7Ghz)
- ram : 32Go RAM : 4 * 8 Go DDR 4 2133Mhz 
- raid :  Raid hardware LSI Megaraid 9361-4i
- storage : 4 * 240Go SSD Intel S3500 in RAID 0
- network : 1 NIC Supermicro Dual port 10Gbit SFP+
- ...

Switch : Supermicro SSE-X3348SR 48 ports 10Gbit SFP+

Kubernetes v1.10.3 via kubeadm (up to date on 2018-05-30)

### Preparation commands

Preparing nodes
cat bench-prepare.sh | lssh 4



#### Test TCP

We will launch iperf3 in tcp mode (default), omitting the first bunch of packets (-O 1) to prevent the TCP Slow start and finally connection on the IP of the server (-c 10.1.1.2)

```Bash
iperf3 -O 1 -c 10.1.1.2
```



#### Test UDP

We will launch iperf3 in udp mode (-u), with unlimited bandwidth (-b 0), using a 2MB buffer (-w 2M), omitting the first bunch of packets (-O 1) and finally connection on the IP of the server (-c 10.1.1.2)

```Bash
iperf3 -u -b 0 -w 2M -O 1 -c 10.1.1.2 
```

output sample :

```
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Jitter    Lost/Total Datagrams
[  4]   0.00-10.00  sec  11.5 GBytes  9.92 Gbits/sec  0.006 ms  112/1513578 (0.0074%)
[  4] Sent 1513578 datagrams

iperf Done.
```

From the output, we will extract the Bandwidth (9.92 Gbits/sec), the Jitter (0.006 ms) and the loss percentage (0.0074%).

#### Test HTTP

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

From the output, we will extract only the average download speed (Avergage Dload)

#### Test FTP

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

From the output, we will extract only the average download speed in the column Avergage Dload (1173M)

#### Test SCP

The SCP test command is a simple openssh download using scp against a OpenSSH server. 

```Bash
scp 10.1.1.2:/home/ubuntu/10G.dat ./
```

output sample :

```
10G.dat                            100%   10GB 267.9MB/s   00:37
```

From the output, we will extract the bandwidth (267.9MB/s)



## Kubernetes 



```
BINONLY=yes ./autokube-multi.sh ubuntu 10.1.1.4 10.1.1.2 10.1.1.3
```



Test HTTP :

```bash
# Creating HTTP Server Pod
kubectl apply -f bench-httpd.yml

# Waiting for pod to be alive
while true; do kubectl get pod|grep http-srv |grep Running && break; sleep 1; done

# Retrieving Pod IP address
IP=$(kubectl get pod/http-srv -o jsonpath='{.status.podIP}')

# Launching benchmark
kubectl run --restart=Never -it --rm bench --image=webofmars/curl-perfs:cmd --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- curl -o /dev/null http://$IP/10G.dat 
```

Test FTP :

```bash
# Creating FTP Server Pod
kubectl apply -f bench-ftpd.yml

# Waiting for pod to be alive
while true; do kubectl get pod|grep ftp-srv |grep Running && break; sleep 1; done

# Retrieving Pod IP address
IP=$(kubectl get pod/ftp-srv -o jsonpath='{.status.podIP}')

# Launching benchmark
kubectl run --restart=Never -it --rm bench --image=webofmars/curl-perfs:cmd --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- curl -o /dev/null ftp://$IP/10G.dat
```

 Test SCP :

```bash
# Creating SSH Server Pod
kubectl apply -f bench-sshd.yml

# Waiting for pod to be alive
while true; do kubectl get pod|grep ssh-srv |grep Running && break; sleep 1; done

# Retrieving Pod IP address
IP=$(kubectl get pod/ssh-srv -o jsonpath='{.status.podIP}')
echo $IP

# Launching benchmark
kubectl run --restart=Never -it --rm bench --image=webofmars/curl-perfs:cmd --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{"kubernetes.io/hostname":"s03"}}}' -- scp root@$IP:/root/10G.dat ./

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

