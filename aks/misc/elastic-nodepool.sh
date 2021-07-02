#!/bin/bash

RG_NAME=temp
CLUSTER=tempaks
NODES_COUNT=1
NODE_SIZE=Standard_DS2_v2
KUBE_VER=1.19.11

echo "Adding nodepool 'elastic' to AKS $CLUSTER with custom sysctl parameters"

status=$(az feature list -o tsv --query "[?contains(name, 'Microsoft.ContainerService/CustomNodeConfigPreview')].{State:properties.state}")

if [[ "$status" != "Registered" ]]; then
  echo "ERROR! CustomNodeConfigPreview is not registered, status is '$status'"
  echo "Please follow these stesp: https://docs.microsoft.com/en-us/azure/aks/custom-node-configuration#register-the-customnodeconfigpreview-preview-feature"
  exit 1
fi

az aks nodepool add \
--name elastic --cluster-name $CLUSTER --resource-group $RG_NAME \
--node-count $NODES_COUNT --node-vm-size $NODE_SIZE \
--kubernetes-version $KUBE_VER \
--linux-os-config ./elastic-node-conf.json