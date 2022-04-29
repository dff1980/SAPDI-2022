# Below instruction to create RKE RKE2 Cluster using Rancher CLI and API.
If you using CLI you can install RKE, but can bootstrap Rancher server.
If you chose API you can bootstrap Rancher server and install RKE & RKE2, but you need be very familiars witch API, web codding and etc.

## Rancher CLI
Witch rancher CLI you can create only RKE, not RKE2 cluster
Currently you need use Web for bootstrap Rancher in web and obtain token.

Deploy CLI
```bash
tar -C /usr/local/bin/ --strip-components=2 -zf rancher-linux-amd64-v2.6.4.tar.gz -x ./rancher-v2.6.4/rancher -v
./rancher-v2.6.4/rancher
```
Create cluster
```bash
rancher login https://192.168.0.11.sslip.io --skip-verify -token token-################################ # see get API_TOKEN below
```

Use rancher command to create cluster.

## Rancher API

[usefully link](https://www.suse.com/c/rancher_blog/automate-k3os-cluster-registration-to-rancher-with-argo-workflows-and-scripting-magic/)

Set grains for minions
```bash
sudo salt '192.168.0.20' grains.append roles rke2-master
sudo salt '192.168.0.2[123]' grains.append roles rke2-worker
```

```bash
 RANCHER_PASS=#########
RANCHER_URL=192.168.0.11.sslip.io
RANCHER_USER=admin
CLUSTER_NAME=test-cluster
CLUSTER_VERSION=v1.22.7+rke2r2

echo "Get bootstrap password"
bootstrapPassword=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}')

echo "Log in to Rancher"
LOGIN_RESPONSE=$(curl -k -s "https://$RANCHER_URL/v3-public/localProviders/local?action=login" -H 'content-type: application/json' --data-binary '{"username":"'$RANCHER_USER'","password":"'$bootstrapPassword'"}')

LOGIN_TOKEN=$(echo $LOGIN_RESPONSE | jq -r .token)

echo "Obtain Rancher API token"
API_RESPONSE=$(curl -k -s "https://$RANCHER_URL/v3/token" -H 'content-type: application/json' -H "Authorization: Bearer $LOGIN_TOKEN" --data-binary '{"type":"token","description":"automation"}')

API_TOKEN=$(echo $API_RESPONSE | jq -r .token)

#It is very important to use the Rancher Server URL without the "/" ending
#rancher agent error level=error msg="Failed to dial steve aggregation server: websocket: bad handshake"
echo "Configure server-url"
RANCHER_SERVER_URL="https://$RANCHER_URL"


curl -k "https://$RANCHER_URL/v3/settings/server-url" -H 'content-type: application/json' -H "Authorization: Bearer $API_TOKEN" -X PUT --data-binary '{"name":"server-url","value":"'$RANCHER_SERVER_URL'"}'

echo "Change admin password"
curl -k "https://$RANCHER_URL/v3/users?action=changepassword" \
 -H 'content-type: application/json' -H "Authorization: Bearer $API_TOKEN" \
  --data-raw '{"currentPassword":"'$bootstrapPassword'","newPassword":"'$RANCHER_PASS'"}'

echo "Create the cluster"
curl -k -s "https://$RANCHER_URL/v1/provisioning.cattle.io.clusters" -H 'content-type: application/json' -H "Authorization: Bearer $API_TOKEN" --data-raw '{"type":"provisioning.cattle.io.cluster","metadata":{"namespace":"fleet-default","name":"'$CLUSTER_NAME'"},"spec":{"rkeConfig":{"chartValues":{"rke2-calico":{}},"machineGlobalConfig":{"cni":"calico"}},"kubernetesVersion":"'$CLUSTER_VERSION'"}}' | jq -r .id

echo "Extract the cluster ID"
CLUSTER_ID=$(curl -k -s "https://$RANCHER_URL/v3/cluster?name=$CLUSTER_NAME" -H 'content-type: application/json' -H "Authorization: Bearer $API_TOKEN" | jq ".data | .[]" | jq -r .id)

###Not needed for rke2
#echo "Generate the cluster registration token"
#CLUSTER_JSON=$(curl -ks "https://$RANCHER_URL/v3/clusterregistrationtoken" -H 'content-type: application/json' -H #"Authorization: Bearer $API_TOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTER_ID'"}')

#echo "Extract the cluster registration token"
#CLUSTER_TOKEN=$(echo $CLUSTER_JSON | jq -r .token)

echo "Get self install command"
install_cmd=$(curl -k -s "https://$RANCHER_URL/v3/clusterregistrationtoken?clusterId=$CLUSTER_ID" -H 'content-type: application/json' -H "Authorization: Bearer $API_TOKEN" | jq ".data | first" | jq -r .insecureNodeCommand)



#kubectl get secrets tls-rancher -n cattle-system -o json | jq -r '.data | ."tls.crt"' | base64 -d > rancher-server-ca.crt
#sudo salt-cp -G "roles:rke2" --chunked rancher-server-ca.crt /etc/pki/trust/anchors/

sudo salt-cp -G "roles:rke2" --chunked /opt/certificates/cacert.pem /etc/pki/trust/anchors/rancher-stend.pem
sudo salt -G "roles:rke2" cmd.run 'update-ca-certificates && c_rehash'
sudo salt -G "roles:rke2-master" cmd.run "$install_cmd --etcd --controlplane --worker"
sudo salt -G "roles:rke2-worker" cmd.run "$install_cmd --worker"
```

