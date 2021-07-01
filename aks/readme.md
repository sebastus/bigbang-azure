# AKS Notes & Gotchas

Any issues found with running on AKS are recorded here

## Elastic Search

Elastic search requires that kernel parameter `vm.max_map_count` is set to 262144 https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html

This will not be the case on the nodes in AKS, there are a number of strategies for setting this including SSH into the nodes and modifying the value manually or running sysctl command via an init-container.

The solution used here is to deploy a seperate AKS nodepool using the [CustomNodeConfigPreview feature](https://docs.microsoft.com/en-us/azure/aks/custom-node-configuration#register-the-customnodeconfigpreview-preview-feature) and set vm.max_map_count on the nodes in that pool. See the script `elastic-nodepool.sh` and `elastic-node-conf.json` in this directory to set this up. The elasticsearch pod are then set to use this nodepool with a `nodeSelector` in the configmap

## Jaeger

Version 1.22.0 would not start (OCI errors about mounting /tmp), forcing the version to be 1.23.0 fixed it. It is suspected [this issue with containerd is the cause ](https://github.com/containerd/containerd/issues/5547)