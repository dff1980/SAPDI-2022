## If you don't use DHCP, login to server and configure temporary network (for connect to server at SSH) 
### Change to your parameters
```bash
ip a a 172.17.149.41/24 dev eth0
ip l s up eth0
ip ro add default via 172.17.149.254
echo "nameserver 172.17.149.254" >> /etc/resolv.conf
```
## Live resize. Resize disk VM on-line and resize partition.

```bash
echo -e "quit\nY\n" | sfdisk /dev/sda --force
partprobe /dev/sda
echo 1 > /sys/block/sda/device/rescan
parted -s /dev/sda resize 3 100%
btrfs filesystem resize max /

```

## Configure your server
```bash
 export reg_code={YOUR_CODE}
SUSEConnect -r ${reg_code}
swapoff -a
systemctl disable kdump --now
systemctl disable firewalld --now
zypper in -y -t pattern enhanced_base base yast2_basis
zypper in yast2-network

yast2 lan

SUSEConnect -p sle-module-containers/15.3/x86_64
zypper in -y docker
usermod -aG docker sles
usermod -aG docker root
chown root:docker /var/run/docker.sock
modprobe br_netfilter
sysctl net.bridge.bridge-nf-call-iptables=1

cat > /etc/sysctl.d/90-rancher.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
EOF

cat > /etc/modules-load.d/modules-rancher.conf <<EOF
br_netfilter
EOF

systemctl enable docker --now

zypper in -y wget screen
```
