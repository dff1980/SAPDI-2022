# SAPDI-2022
 Infrastructure for SAP Data Intelligence 3.1 with air gap.

 [SAP Data Intelligence 3.1 on Rancher Kubernetes Engine 2](https://documentation.suse.com/sbp/all/html/RKE2-SAP-DI31/index.html)

######
#Rancher #RKE2 #Longhorn #SLES15SP3 #Salt #MinIO

## Requirements

- Virtual or Hardware server 
- SUSE SLES trial key
- Local DNS Server
  for test:
  - [sslip.io](https://github.com/cunnie/sslip.io) - Used in this document.
  - [nip.io](https://github.com/exentriquesolutions/nip.io)
- Local NTP Server
- SSD for Longhorn on Worker Nodes
- Server with docker and connect to Internet to download images.

### Minimal hardware requirements for an SAP DI 3 deployment for production use

- 1x Jump Host

    4 vCPU

    16 GiB RAM

    1 x HDD - > 150 GB (+300 for registry)

- 1x dedicate server for Rancher

    4 vCPU
    
    16 GiB RAM

    1 x HDD - > 100 GB

- 3x RKE2 Master Node - role: ETCD, Controls Plane

    4 vCPU
    
    16 GiB RAM

    1 x HDD - > 120 GB

- 4x RKE2 Worker Node - role: Workers

    16 vCPU
    
    64 GiB RAM

    1 x HDD - > 120 GB

### Version
- RKE2 v1.22.7+rke2r2
- Rancher v2.6.4
- SLES 15 SP3
- Longhorn v1.2
- MinIO v3.6.6
- Helm v3.8.2
- kubectl latest

### Network Architecture
All server connect to LAN network (isolated from Internet).

## Download images
From a system that has access to the internet, fetch the latest Helm chart, images and utilities  and copy the resulting manifests to a system that has access to the Rancher server cluster.

For install server from JeOS image you can use a this [script](front_server_JeOS-install_script.md).

0. Download & install CLI interface helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

1. Find the required assets for your Rancher version

Go to our [releases page](https://github.com/rancher/rancher/releases), find the Rancher v2.x.x release that you want to install, and click Assets. Note: Don’t use releases marked *rc* or *Pre-release*, as they are not stable for production environments.

From the release’s Assets section, download the following files, which are required to install Rancher in an air gap environment:
- rancher-images.txt	This file contains a list of images needed to install Rancher, provision clusters and user Rancher tools.
- rancher-save-images.sh	This script pulls all the images in the rancher-images.txt from Docker Hub and saves all of the images as rancher-images.tar.gz
- rancher-load-images.sh	This script loads images from the rancher-images.tar.gz file and pushes them to your private registry.

2. Collect the cert-manager image
In a Kubernetes Install, if you select to use the Rancher default self-signed TLS certificates, you must add the cert-manager image to rancher-images.txt as well.

  1. Fetch the latest cert-manager Helm chart and parse the template for image details:
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm fetch jetstack/cert-manager --version v1.7.1
helm template ./cert-manager-v1.7.1.tgz | awk '$1 ~ /image:/ {print $2}' | sed s/\"//g >> ./rancher-images.txt
```
  2. Sort and unique the images list to remove any overlap between the sources:
```bash
sort -u rancher-images.txt -o rancher-images.txt
```

3. Collect the RKE2 images

Go to our [releases page](https://github.com/rancher/rke2/releases), find the RKE2 release that you want to install, and click Assets.
From the release’s Assets section, download the following files, which are required to install RKE2 in an air gap environment:
 
 __rke2-images-all.linux-amd64.txt__

  1. Add RKE2 images to rancher-images.txt:
```bash
cat rke2-images-all.linux-amd64.txt >> ./rancher-images.txt
```
  2. Sort and unique the images list to remove any overlap between the sources:
```bash
sort -u rancher-images.txt -o rancher-images.txt
```
4. Collect the MinIO images
```bash
helm repo add minio https://charts.min.io/
helm repo update
helm fetch minio/minio --version v3.6.6
helm template ./minio-3.6.6.tgz | awk '$1 ~ /image:/ {print $2}' | sed s/\"//g >> ./rancher-images.txt
```
  2. Sort and unique the images list to remove any overlap between the sources:
```bash
sort -u rancher-images.txt -o rancher-images.txt
```

5. Save the images to your workstation
  1. Make rancher-save-images.sh an executable:

```bash
chmod +x rancher-save-images.sh
```
  2. Run rancher-save-images.sh with the rancher-images.txt image list to create a tarball of all the required images:
```bash
./rancher-save-images.sh --image-list ./rancher-images.txt
```
Result: Docker begins pulling the images used for an air gap install. Be patient. This process takes a few minutes. When the process completes, your current directory will output a tarball named rancher-images.tar.gz. Check that the output is in the directory.

6. Add the Rancher Helm Chart Repository

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm fetch rancher-stable/rancher --version=v2.6.4
```

7. Render the cert-manager template

```bash
export registry_url=192.168.0.10.sslip.io:5000
helm template cert-manager ./cert-manager-v1.7.1.tgz --output-dir . \
    --namespace cert-manager \
    --set image.repository=${registry_url}/quay.io/jetstack/cert-manager-controller \
    --set webhook.image.repository=${registry_url}/quay.io/jetstack/cert-manager-webhook \
    --set cainjector.image.repository=${registry_url}/quay.io/jetstack/cert-manager-cainjector \
    --set startupapicheck.image.repository=${registry_url}/quay.io/jetstack/cert-manager-ctl
```
8. Download the cert-manager CRD

```bash
curl -L -o cert-manager/cert-manager-crd.yaml https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
```

9. Render the Rancher template
 
Chose option 1 - for your own certificate or 2 - for self-signed certificate.

  1. For Your Own Certificate.
```bash
export rancher_fqdn=192.168.0.11.sslip.io
export registry_url=192.168.0.10.sslip.io:5000
helm template rancher ./rancher-2.6.4.tgz --output-dir . \
  --no-hooks \
  --namespace cattle-system \
  --set hostname=${rancher_fqdn} \
  --set rancherImage=${registry_url}/rancher/rancher \
  --set systemDefaultRegistry=${registry_url} \
  --set useBundledSystemChart=true \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=secret \
  --set replicas=1 \
  --set privateCA=true \
  --version=2.6.4
```
  2. For Self-Signed Certificate

--no-hooks \ # prevent files for Helm hooks from being generated
--set systemDefaultRegistry=${registry_url} \ # Set a default private registry to be used in Rancher
--set useBundledSystemChart=true # Use the packaged Rancher system charts

```bash
export rancher_fqdn=192.168.0.11.sslip.io
export registry_url=192.168.0.10.sslip.io:5000
helm template rancher ./rancher-2.6.4.tgz --output-dir . \
    --no-hooks \
    --namespace cattle-system \
    --set hostname=${rancher_fqdn} \
    --set certmanager.version=1.7.1 \
    --set rancherImage=${registry_url}/rancher/rancher \
    --set systemDefaultRegistry=${registry_url} \
    --set replicas=1 \
    --set useBundledSystemChart=true \
    --version=2.6.4
```
*You can use option --kube-version, for example --kube-version v1.20.13*

10. Download CLI utilities
```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
wget https://github.com/minio/operator/releases/latest/download/kubectl-minio_linux_amd64.zip
unzip kubectl-minio_linux_amd64.zip kubectl-minio
rm kubectl-minio_linux_amd64.zip
wget https://github.com/rancher/rke2/releases/download/v1.22.7%2Brke2r2/rke2.linux-amd64.tar.gz
wget https://github.com/rancher/cli/releases/download/v2.6.4/rancher-linux-amd64-v2.6.4.tar.gz
```

11. Get registry images
```bash
 docker pull httpd:2
 docker save httpd:2 |  gzip --stdout > httpd.gz
 docker pull registry:2
 docker save registry:2 |  gzip --stdout > registry.gz
```


Copy to an external data store:
- rancher-load-images.sh
- rancher-images.tar.gz
- rancher-images.txt
- ./rancher
- ./cert-manager
- kubectl CLI
- kubectl-minio CLI
- rke2.linux-amd64.tar.gz
- rancher-linux-amd64-v2.6.4.tar.gz
- httpd.gz
- registry.gz
## Install SLES on all servers

### Preparations

- Get a SUSE Linux Enterprise Server subscription.
- Download the installation media for SUSE Linux Enterprise Server 15 SP3. (Full ISO, for example)
- All system need access to update repositories (RMT) or installation media.

######
You can create the own RMT server using the next [instruction](rmt.md).
#### For All Servers

- Static IP for all Nodes.
- Configured NTP time synchronization. (salt sate)
- Disabled firewall. (salt sate)
- Enabled SSHD. (salt sate)
- Disabled Kdump. (salt sate)
- Disabled swap. (salt sate)
- Existing user _sles_. (salt sate)
- One root partition without splitting.
- Boot in text mode.
- Installed enhanced base pattern (salt sate)
- Installed and configured Salt minion

```bash
sudo zypper in -y salt-minion
sudo echo "master: <Jump Host IP>" > /etc/salt/minion # Change <Jump Host IP> for your data.
sudo systemctl enable salt-minion --now
```
#### For Jump Host

- Installed and configured docker (salt sate)
- Installed and configured Salt Master

```bash
sudo zypper in -y salt-master
sudo systemctl enable salt-master --now
```
### Configure servers

At Jump Host, run the next command:
```bash
zypper in -y sudo
```
Check what the all minions in the list.

Put state file from this project to /srv/salt/

From user _sles_:

```bash
ssh-keygen -t rsa -b 4096 -N "" -f /home/sles/.ssh/id_rsa # Created ssh key pair
sudo mkdir -p /srv/salt/ssh/
sudo cp /home/sles/.ssh/id_rsa.pub /srv/salt/ssh/
```

```bash
sudo mkdir -p /srv/salt/main/
su - # Issue #01 need change to sudo
cat > /srv/salt/main/ntp.conf <<EOF
server 192.168.0.1 iburst
EOF
```


Check and add all minions.

```bash
sudo salt-key -L
sudo salt-key -A -y
sudo salt-key -L
```

Set grains for server role.

```bash
sudo salt '<Rancher Server Minion>' grains.append roles rancher # Change <Rancher Server Minion> for your data.
sudo salt '<RKE2 Server Minions>' grains.append roles rke2 # Run for all RKE2 role servers. Change <RKE2 Server Minions> for your data.
sudo salt '<Jump Host Minion>' grains.append roles jumphost # Change <Jump Host Minion> for your data.

sudo salt '*' state.apply
```
Check server requirements status.

```bash
sudo salt '*' cmd.run 'systemctl status firewalld' # Check status firewalld
sudo salt '*' cmd.run 'systemctl status kdump' # Check status Kdump
sudo salt '*' cmd.run 'cat /proc/swaps' # Check status swap
sudo salt '*' cmd.run 'systemctl status sshd' # Check status SSHD
sudo salt '*' cmd.run 'systemctl status chronyd' # Check status choryd
sudo salt '*' cmd.run 'chronyc sources' # Check configuration chronyd
```
## Make own certificate
At Jump host, run commands below.

```bash

sudo zypper in -y gnutls

sudo mkdir -p /opt/certificates
cd /opt/certificates
sudo ./certs.sh --rancher_fqdn 192.168.0.11.sslip.io --rancher_ip 192.168.0.11 --registry_fqdn 192.168.0.10.sslip.io --registry_ip 192.168.0.10
cd ..
```
## Run local registry on Jump Host

Copy air gap data (images and utilities) to Jump Host from the external data store:

- httpd.gz
- registry.gz

```bash
docker load --input httpd.gz
docker load --input registry.gz
```

```bash
su -
mkdir -p /opt/docker-certs
mkdir -p /opt/docker-auth
mkdir -p /opt/registry

cd /opt/certificates/
cp registry.key.pem /opt/docker-certs/tls.key
openssl x509 -inform PEM -in registry.cert.pem -out /opt/docker-certs/tls.crt

docker run \
  --entrypoint htpasswd \
  httpd:2 -Bbn geeko P@ssw0rd > /opt/docker-auth/htpasswd

docker run -d \
  --restart=always \
  --name registry \
  -v /opt/docker-certs:/certs:ro \
  -v /opt/docker-auth:/auth:ro \
  -v /opt/registry:/var/lib/registry \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  -e "REGISTRY_HTTP_ADDR=0.0.0.0:8443" \
  -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/tls.crt" \
  -e "REGISTRY_HTTP_TLS_KEY=/certs/tls.key" \
  -e "REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry" \
  -p 8443:8443 \
  registry:2

docker run -d \
  --restart=always \
  --name registry-anonymous \
  -v /opt/docker-certs:/certs:ro \
  -v /opt/docker-auth:/auth:ro \
  -v /opt/registry:/var/lib/registry:ro \
  -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/tls.crt" \
  -e "REGISTRY_HTTP_TLS_KEY=/certs/tls.key" \
  -e "REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry" \
  -p 5000:5000 \
  registry:2

zypper in -y jq

export registry_fqdn=192.168.0.10.sslip.io # Your Registry Host (Jump Host Host)
export registry_url="https://${registry_fqdn}:8443"

echo "$(jq --arg urlarg "${registry_url}" '. += {"registry-mirrors": [$urlarg]}' /etc/docker/daemon.json)" > /etc/docker/daemon.json

cd /opt/certificates
mkdir -p /etc/docker/certs.d/${registry_url}
cp ${registry_fqdn}.cert ${registry_fqdn}.key ca.crt /etc/docker/certs.d/${registry_url}
cd ..

systemctl restart docker
```
## Import images to local registry

Copy air gap data (images and utilities) to Jump Host from the external data store:
- rancher-load-images.sh
- rancher-images.tar.gz
- rancher-images.txt
- ./rancher
- ./cert-manager
- kubectl CLI
- kubectl-minio CLI
- rke2.linux-amd64.tar.gz
- rancher-linux-amd64-v2.6.4.tar.gz

At Jump host, run commands below.

```bash
sudo cp kubectl /usr/local/bin/
sudo cp kubectl-minio /usr/local/bin/
mkdir -p /srv/salt/rke2/
sudo cp rke2.linux-amd64.tar.gz /srv/salt/rke2
sudo chmod +x /usr/local/bin/kubectl-minio
sudo chmod +x /usr/local/bin/kubectl

export registry_fqdn=192.168.0.10.sslip.io # Your Registry Host (Jump Host Host)
export registry_url="https://${registry_fqdn}:8443"

docker login ${registry_url} # geeko/P@ssw0rd

chmod +x rancher-load-images.sh
./rancher-load-images.sh -l rancher-images.txt -r ${registry_fqdn}:8443

```
## Install RKE2 on Rancher Server

```bash
# --chunked see BUG https://github.com/saltstack/salt/issues/59899  real slow copy
sudo salt-cp -G "roles:rancher" --chunked /opt/certificates/cacert.pem /etc/pki/trust/anchors/rancher-stend.pem
sudo salt -G "roles:rancher" cmd.run 'update-ca-certificates && c_rehash'

export registry_fqdn=192.168.0.10.sslip.io # Your Registry Host (Jump Host Host)
export registry_uri="${registry_fqdn}:5000"

#salt '*' file.manage_file /etc/httpd/conf.d/httpd.conf '' '{}' salt://http/httpd.conf '{hash_type: 'md5', 'hsum': <md5sum>}' root root '755' base ''
# --chunked see BUG https://github.com/saltstack/salt/issues/59899  real slow copy
sudo salt-cp -G "roles:rancher" --chunked --no-compression /srv/salt/rke2/rke2.linux-amd64.tar.gz /tmp/
sudo salt -G "roles:rancher" cmd.run 'tar xzf "/tmp/rke2.linux-amd64.tar.gz" -C "/usr/local"'
sudo salt -G "roles:rancher" cmd.run 'mkdir -p /etc/rancher/rke2'
sudo salt -G "roles:rancher" cmd.run "echo 'system-default-registry: \"'${registry_uri}'\"' > /etc/rancher/rke2/config.yaml"
sudo salt -G "roles:rancher" cmd.run 'systemctl enable rke2-server --now'
```

## Install Rancher Server
```bash
#Since this feature allows a minion to push a file up to the master server it is disabled by default for security purposes. To enable, set file_recv to True in the master configuration file, and restart the master.
#sudo salt -G "roles:rancher" cp.push /etc/rancher/rke2/rke2.yaml
#cp /var/cache/salt/master/minions/{minion-id}/files/rke2.yaml ./kubeconfig-rancher.yaml # Set {minion-id} to Rancher minion
#salt -G "roles:rancher" cmd.run 'cat /etc/rancher/rke2/rke2.yaml' > ./kubeconfig-rancher.yaml
scp 192.168.0.11:/etc/rancher/rke2/rke2.yaml kubeconfig-rancher.yaml
sed -i 's/127.0.0.1/192.168.0.11/' ./kubeconfig-rancher.yaml
```

For self-signed certificate. Skip this step for own CA 
```bash
export KUBECONFIG=~/kubeconfig-rancher.yaml
kubectl create namespace cert-manager
kubectl apply -f cert-manager/cert-manager-crd.yaml
kubectl apply -R -f ./cert-manager
```

```bash
export KUBECONFIG=~/kubeconfig-rancher.yaml
kubectl create namespace cattle-system
kubectl -n cattle-system apply -R -f ./rancher
```

## Install RKE2 from Rancher Server
What about use CLI?
You can create bootstrap Rancher server and create RKE using the next [instruction](rancher-cli.md).

Go to Rancher web interface and do next:
 - Create custom cluster and obtain an installation command
 - Start the installation command at node

```bash
sudo salt '192.168.0.20' grains.append roles rke2-master
sudo salt '192.168.0.2[123]' grains.append roles rke2-worker

sudo salt-cp -G "roles:rke2" --chunked /opt/certificates/cacert.pem /etc/pki/trust/anchors/rancher-stend.pem
sudo salt -G "roles:rke2" cmd.run 'update-ca-certificates && c_rehash'
sudo salt -G "roles:rke2-master" cmd.run "INSTALL CMD FOR Masters"
sudo salt -G "roles:rke2-worker" cmd.run "INSTALL CMD FOR Workers"
```
 - Install Longhorn
 - Install Minio
Init MinIO
```bash
kubectl minio version
kubectl minio init
```
 - Create ingress for MinIO Console 
Obtain token
```bash
kubectl get secrets -n minio-operator -o=jsonpath='{.items[?(@.metadata.annotations.kubernetes\.io/service-account\.name=="console-sa")].data.token}' | base64 -d; echo
```
 - Create MiniIO tenant
Login to MinIO console with token from previously step.
 - create ingress for MinIO Console
You needed SSL Certificate with Subject Alternative Name for FQDN. Because an installation system for SAP DI doesn't approve Self Signed standard certificate for Nginx ingress.
Create an ingress.
Add Annotations to the ingress.
```
nginx.ingress.kubernetes.io/backend-protocol: HTTPS
nginx.ingress.kubernetes.io/proxy-body-size: 10G
```
 - Check S3
# Appendix
If you use the registry in the Rancher (for example Harbor) you need to add annotations to ingress:
```
  annotations:
          nginx.ingress.kubernetes.io/proxy-connect-timeout: "3600"
          nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
          nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```
