#!/bin/bash

#
# This is a script that deploys BigBang into Azure via AKS
#

scriptPath=$(dirname "$0")

test -f secrets.sh        || { echo -e "💥 Error! secrets.sh not found, please create"; exit 1; }
test -f deploy-vars.sh    || { echo -e "💥 Error! deploy-vars.sh not found, please create"; exit 1; }
which sops > /dev/null    || { echo -e "💥 Error! Command sops not installed"; exit 1; }
which az > /dev/null      || { echo -e "💥 Error! Command az not installed"; exit 1; }
which kubectl > /dev/null || { echo -e "💥 Error! Command kubectl not installed"; exit 1; }

source $scriptPath/secrets.sh
source $scriptPath/deploy-vars.sh

for varName in IRON_BANK_USER IRON_BANK_PAT GITHUB_USER GITHUB_PAT; do
  varVal=$(eval echo "\${$varName}")
  [[ -z $varVal ]] && { echo "💥 Error! Required variable '$varName' is not set!"; varUnset=true; }
done
[[ $varUnset ]] && exit 1

# This part creates the GPG keys without user input
gpg -K $GPG_KEY_NAME > /dev/null 2>&1
if [[ $? == "2" ]]; then
  echo "### Creating GPG keys unattended"
  gpg --quick-generate-key --batch --passphrase='' $GPG_KEY_NAME
  fingerPrint=$(gpg -K $GPG_KEY_NAME | sed -e 's/ *//;2q;d;')
  gpg --quick-add-key --batch --passphrase='' "${fingerPrint}" rsa4096 encr
  sed -i "s/pgp: FALSE_KEY_HERE/pgp: ${fingerPrint}/" $scriptPath/../.sops.yaml
  
  echo "### Updating .sops.yaml in git"
  git add $scriptPath/../.sops.yaml
  git commit -m "Updated .sops.yaml by deployment script $(date)"
  git push
fi

fingerPrint=$(gpg -K $GPG_KEY_NAME | sed -e 's/ *//;2q;d;')
echo "### Key $GPG_KEY_NAME ($fingerPrint) already exists, skipping creation"

set -e

# Create & encrpyt the secrets.enc.yaml file from template using sops and envsubst
echo "### Creating & encrypting dev/secrets.enc.yaml"
envsubst < $scriptPath/secrets.enc.yaml.template > $scriptPath/../base/secrets.enc.yaml
sops --encrypt --in-place $scriptPath/../base/secrets.enc.yaml
git add $scriptPath/../base/secrets.enc.yaml
git commit -m "Updated by deployment script $(date)"
git push

if [[ $DEPLOY_AKS == "true" ]]; then
  echo "### Deploying AKS cluster & Azure resources, please wait this can take some time"
  az deployment sub create -f ${scriptPath}/template/main.bicep -l $AZURE_REGION -n $AZURE_DEPLOY_NAME --parameters resGroupName=$AZURE_RESGRP location=$AZURE_REGION
fi

clusterName=$(az deployment sub show --name $AZURE_DEPLOY_NAME --query "properties.outputs.clusterName.value" -o tsv)
echo "### Connecting to cluster '$clusterName'"
az aks get-credentials --overwrite-existing -g $AZURE_RESGRP -n $clusterName

set +e
echo "### Creating namespaces '$NAMESPACE' & 'flux-system'"
kubectl create namespace $NAMESPACE
kubectl create namespace flux-system

echo "### Creating secret sops-gpg in $NAMESPACE"
gpg --export-secret-key --armor ${fingerPrint} | kubectl create secret generic sops-gpg -n $NAMESPACE --from-file=bigbangkey.asc=/dev/stdin

echo "### Creating secret docker-registry in flux-system"
kubectl create secret docker-registry private-registry --docker-server=registry1.dso.mil --docker-username="${IRON_BANK_USER}" --docker-password="${IRON_BANK_PAT}" -n flux-system

echo "### Creating secret private-git in $NAMESPACE"
kubectl create secret generic private-git --from-literal=username=${GITHUB_USER} --from-literal=password=${GITHUB_PAT} -n bigbang

echo "### Installing flux from bigbang install script"
if [[ $DEPLOY_FLUX == "true" ]]; then
  rm -rf $scriptPath/bigbang
  git clone $BB_REPO $scriptPath/bigbang
  pushd $scriptPath/bigbang
  ./scripts/install_flux.sh \
    --registry-username "${IRON_BANK_USER}" \
    --registry-password "${IRON_BANK_PAT}" \
    --registry-email bigbang@bigbang.dev 
  popd
fi

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
kubectl get -n $NAMESPACE gitrepositories,kustomizations -A
