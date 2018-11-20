#!/bin/bash

PrivateClusterFile=kubeconfig.privatecluster.json
PublicClusterFile=kubeconfig.publiccluster.json

while [[ $# -gt 0 ]]
do
value="$1"

case $value in
	--clusterType)
	clusterType="$2"
	shift 2
	;;
	--sshkey)
	sshKeyPath="$2"
	shift 2
	;;
	--subid)
	subName="$2"
	shift 2
        ;;
	--resourceGroup)
	rgName="$2"
	shift 2
        ;;
	--vNetName)
	vNetName="$2"
	shift 2
        ;;
	--subnetName)
	subnetName="$2"
	shift 2
        ;;
	--dnsPrefix)
	dnsPrefix="$2"
	shift 2
	;;	
	*)
	echo "Invalid argument $1"
	exit 1
	;;	
esac
done
 
if [ "${clusterType,,}" = "public" ];

then

        wget -P $HOME/kubedeploy https://raw.githubusercontent.com/cwallen25/K8s_Azure/master/$PublicClusterFile

FileName=$PublicClusterFile

elif [ "${clusterType,,}" = "private" ];
then

        wget -P $HOME/kubedeploy https://raw.githubusercontent.com/cwallen25/K8s_Azure/master/$PrivateClusterFile

FileName=$PrivateClusterFile

else
        echo "The type of cluster provided is invalid. Valid values are public or private"
        exit 4
fi

subId=$(az account show -s "$subName" | jq -r .id)
rgroupId=$(az group list --query "[?name=='$rgName']" | jq -r '.[] | .id')
vNet=$(az network vnet show -g $rgName -n $vNetName)
vNetCidr=$(az network vnet show -g $rgName -n $vNetName | jq -r '.addressSpace | .addressPrefixes[]')
subnet=$(echo $vNet | jq -r '.subnets[] | select(.id | contains("'$subnetName'")) | .id') 
subnetPrefix=$(echo $vNet | jq -r '.subnets[] | select(.id | contains("'$subnetName'")) | .addressPrefix')

subnetIP=$( echo $subnetPrefix | tr -d / | sed 's/024/239/')

svcPrincipal=$(az ad sp create-for-rbac --role="Contributor" --scopes=$rgroupId)

spAppId=$(echo $svcPrincipal | jq -r .appId)
spSecret=$(echo $svcPrincipal | jq -r .password)

sed -i -e "s,\"SSHKEY\",\"$(cat $sshKeyPath)\"," $HOME/kubedeploy/$FileName
sed -i -e "s,\"CLUSTERDNSPREFIX\",\"${dnsPrefix}\"," $HOME/kubedeploy/$FileName
sed -i -e "s,\"VNETRESOURCEID\",\"${subnet}\"," $HOME/kubedeploy/$FileName
sed -i -e "s,\"FIRSTAVAILABLEIP\",\"${subnetIP}\"," $HOME/kubedeploy/$FileName
sed -i -e "s,\"VNETCIDR\",\"${vNetCidr}\"," $HOME/kubedeploy/$FileName
sed -i -e "s,\"SPAPPID\",\"${spAppId}\"," $HOME/kubedeploy/$FileName
sed -i -e "s,\"SPPASSWORD\",\"${spSecret}\"," $HOME/kubedeploy/$FileName

cat $HOME/kubedeploy/$FileName

