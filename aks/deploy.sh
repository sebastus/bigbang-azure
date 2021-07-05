#!/bin/bash

#
# This is a script that deploys BigBang into Azure via AKS
#

set -e
scriptPath=$(dirname "$0")
deploymentName="bigbang"
namespace="bigbang"
gpgKeyName="bigbang-sops"
bigbangRepo="https://repo1.dso.mil/platform-one/big-bang/bigbang.git"

test -f secrets.sh || { echo -e "💥 Error! secrets.sh not found, please create"; exit 1; }
test -f deploy-vars.sh || { echo -e "💥 Error! deploy-vars.sh not found, please create"; exit 1; }
which sops > /dev/null || { echo -e "💥 Error! Command sops not installed"; exit 1; }
which az > /dev/null || { echo -e "💥 Error! Command az not installed"; exit 1; }
which kubectl > /dev/null || { echo -e "💥 Error! Command kubectl not installed"; exit 1; }

source $scriptPath/secrets.sh
source $scriptPath/deploy-vars.sh

for varName in IRON_BANK_USER IRON_BANK_PAT GITHUB_USER GITHUB_PAT; do
  varVal=$(eval echo "\${$varName}")
  [[ -z $varVal ]] && { echo "💥 Error! Required variable '$varName' is not set!"; varUnset=true; }
done
[[ $varUnset ]] && exit 1

echo "### Creating & encrypting dev/secrets.enc.yaml"
envsubst < $scriptPath/secrets.enc.yaml.template > $scriptPath/../base/secrets.enc.yaml
sops --encrypt --in-place $scriptPath/../base/secrets.enc.yaml
git add $scriptPath/../base/secrets.enc.yaml
git commit -m "chore: updated secrets.enc.yaml"
git push

if [[ $DEPLOY_AKS == "true" ]]; then
  echo "### Deploying AKS cluster & Azure resources, please wait this can take some time"
  az deployment sub create -f ${scriptPath}/template/main.bicep -l $AZURE_REGION -n $deploymentName --parameters resGroupName=$AZURE_RESGRP location=$AZURE_REGION
fi

clusterName=$(az deployment sub show --name $deploymentName --query "properties.outputs.clusterName.value" -o tsv)
echo "### Connecting to cluster '$clusterName'"
az aks get-credentials --overwrite-existing -g $AZURE_RESGRP -n $clusterName

set +e
echo "### Creating namespaces '$namespace' & 'flux-system'"
kubectl create namespace $namespace
kubectl create namespace flux-system

echo "### Creating secret sops-gpg in $namespace"
fingerPrint=$(gpg -K $gpgKeyName | sed -e 's/ *//;2q;d;')
gpg --export-secret-key --armor ${fingerPrint} | kubectl create secret generic sops-gpg -n $namespace --from-file=bigbangkey.asc=/dev/stdin

echo "### Creating secret docker-registry in flux-system"
kubectl create secret docker-registry private-registry --docker-server=registry1.dso.mil --docker-username="${IRON_BANK_USER}" --docker-password="${IRON_BANK_PAT}" -n flux-system

echo "### Creating secret private-git in $namespace"
kubectl create secret generic private-git --from-literal=username=${GITHUB_USER} --from-literal=password=${GITHUB_PAT} -n bigbang

echo "### Installing flux from bigbang install script"
rm -rf $scriptPath/bigbang
git clone $bigbangRepo $scriptPath/bigbang
pushd $scriptPath/bigbang
./scripts/install_flux.sh \
  --registry-username "${IRON_BANK_USER}" \
  --registry-password "${IRON_BANK_PAT}" \
  --registry-email bigbang@bigbang.dev 
popd

echo "### Removing flux-system 'allow-scraping' network policy"
# If we don't remove this the kustomisation will never reconcile!
kubectl delete netpol -n flux-system allow-scraping

echo "### Deploying BigBang!"
pushd $scriptPath/../dev
kubectl apply -f bigbang.yaml
popd

echo "### Sleeping..."
sleep 15

echo "### Verifying gitrepositories & kustomizations"
kubectl get -n $namespace gitrepositories,kustomizations -A
