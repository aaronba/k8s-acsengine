#!/bin/bash

set -e
set -o pipefail

PrivateClusterFile=$HOME/k8s-acsengine/kubeconfig.privatecluster.json
PublicClusterFile=$HOME/k8s-acsengine/kubeconfig.publiccluster.json

while [[ $# -gt 0 ]]
do
value="$1"

case $value in
	--admin-username)
	userName="$2"
	shift 2
	;;
	--cluster-type)
	clusterType="$2"
	shift 2
	;;
	--ssh-key)
	sshKeyPath="$2"
	shift 2
	;;
	--subscription-id)
	subName="$2"
	shift 2
        ;;
	--resource-group)
	rgName="$2"
	shift 2
        ;;
	--resource-location)
	resourceLocation="$2"
	shift 2
	;;
	--vnet-name)
	vNetName="$2"
	shift 2
        ;;
	--subnet-name)
	subnetName="$2"
	shift 2
        ;;
	--dns-prefix)
	dnsPrefix="$2"
	shift 2
	;;
	*)
	echo "Invalid argument $1"
	exit 1
	;;	
esac
done

if ! [ -f $sshKeyPath ]; then
echo "SSH key path is not valid"
exit 1
fi
 
if [ "${clusterType,,}" = "public" ];
then

FileName=$PublicClusterFile

elif [ "${clusterType,,}" = "private" ];
then

FileName=$PrivateClusterFile

else
        echo "The type of cluster provided is invalid. Valid values are public or private"
        exit 4
fi

#az cloud set --name AzureUSGovernment
#az login
#az account set -s $subName


subId=$(az account show -s "$subName" | jq -r .id)
rgroupId=$(az group list --query "[?name=='$rgName']" | jq -r '.[] | .id')
vNet=$(az network vnet show -g $rgName -n $vNetName)
vNetCidr=$(az network vnet show -g $rgName -n $vNetName | jq -r '.addressSpace | .addressPrefixes[]')
subnet=$(echo $vNet | jq -r '.subnets[] | select(.id | contains("'$subnetName'")) | .id') 
subnetPrefix=$(echo $vNet | jq -r '.subnets[] | select(.id | contains("'$subnetName'")) | .addressPrefix')
subnetIP=$(echo $subnetPrefix | tr -d / | sed 's/024/239/')

if ! [[ -z $subnet || -z $subnetPrefix || -z $subnetIP ]];
then

svcPrincipal=$(az ad sp create-for-rbac --role="Contributor" --scopes=$rgroupId)
spAppId=$(echo $svcPrincipal | jq -r .appId)
spSecret=$(echo $svcPrincipal | jq -r .password)

{
jq ".properties.masterProfile.dnsPrefix=\"${dnsPrefix}\"" | \
jq ".properties.masterProfile.vnetSubnetId=\"${subnet}\"" | \
jq ".properties.masterProfile.firstConsecutiveStaticIP=\"${subnetIP}\"" | \
jq ".properties.masterProfile.vnetCidr=\"${vNetCidr}\"" | \
jq ".properties.agentPoolProfiles[].vnetSubnetId=\"${subnet}\"" | \
jq ".properties.linuxProfile.adminUsername=\"${userName}\"" | \
jq ".properties.linuxProfile.ssh.publicKeys[].keyData=\"$(cat $sshKeyPath | awk '{print $1,$2}')\"" | \
jq ".properties.servicePrincipalProfile.clientId=\"${spAppId}\"" | \
jq ".properties.servicePrincipalProfile.secret=\"${spSecret}\"" 
} < $FileName > $HOME/k8s-acsengine/azureKubeDeploy.json

echo "Deployment JSON is located at" $HOME/k8s-acsengine/azureKubeDeploy.json

else
echo "Unable to find subnet information. Check the subnet name to ensure it is spelled correctly"
exit 1
fi
