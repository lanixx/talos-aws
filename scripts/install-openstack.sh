#!/bin/bash

export KUBECONFIG="$(pwd)/kubeconfig"
export TALOSCONFIG="$(pwd)/talosconfig"
export YAOOK_OP_NAMESPACE="yaook"

cd "$(dirname "$0")/.."

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl create namespace "$YAOOK_OP_NAMESPACE"

kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl -n local-path-storage patch configmap local-path-config --type merge -p \
  '{"data":{"config.json":"{\"nodePathMap\":[{\"node\":\"DEFAULT_PATH_FOR_NON_LISTED_NODES\",\"paths\":[\"/var/local-path-provisioner\"]}]}"}}'
kubectl -n local-path-storage rollout restart deploy/local-path-provisioner
kubectl -n local-path-storage rollout status deploy/local-path-provisioner

kubectl label namespace local-path-storage \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged \
  --overwrite

kubectl label namespace default \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged \
  --overwrite

kubectl label namespace $YAOOK_OP_NAMESPACE \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged \
  --overwrite

kubectl -n local-path-storage rollout restart deployment/local-path-provisioner

openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=YAOOK-CA"
kubectl create secret tls root-ca --key ca.key --cert ca.crt
kubectl apply -f https://gitlab.com/yaook/operator/-/raw/devel/docs/user/guides/quickstart-guide/cert-manager.yaml

helm repo add yaook https://charts.yaook.cloud/operator/stable/
helm install -n default yaook-crds yaook/crds
helm repo update

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-stack-prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace


for node in $(kubectl get nodes --no-headers | awk '{print $1}'); do
  kubectl taint node "$node" node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
done

export op_and_os_labels="any.yaook.cloud/api=true infra.yaook.cloud/any=true operator.yaook.cloud/any=true \
  key-manager.yaook.cloud/barbican-any-service=true block-storage.yaook.cloud/cinder-any-service=true \
  compute.yaook.cloud/nova-any-service=true ceilometer.yaook.cloud/ceilometer-any-service=true \
  key-manager.yaook.cloud/barbican-keystone-listener=true gnocchi.yaook.cloud/metricd=true \
  infra.yaook.cloud/caching=true network.yaook.cloud/neutron-northd=true \
  network.yaook.cloud/neutron-ovn-agent=true image.yaook.cloud/glance-any-service=true"

# KORRIGIERT: Alle Nodes nehmen (funktioniert auch für control-plane-as-worker)
op_and_os_nodes="$(kubectl get nodes --no-headers | awk '{print $1}')"
export op_and_os_nodes
echo -e "Nodes to label:\n$op_and_os_nodes"

for node in $op_and_os_nodes; do
   kubectl label node "$node" $op_and_os_labels --overwrite
done

# Hypervisor-Labels
for node in $op_and_os_nodes; do
   kubectl label node "$node" compute.yaook.cloud/hypervisor=true --overwrite
   kubectl label node "$node" compute.yaook.cloud/hypervisor-type=qemu --overwrite
done

YAOOK_VERSION=$(helm search repo yaook/crds -o json | jq -r '.[0].version')
for operator in "infra" "keystone" "keystone-resources" "glance" "nova" "nova-compute" "neutron" "neutron-ovn" "horizon"; do
   echo "Installing yaook/$operator-operator via helm:";
   helm upgrade --install --version "$YAOOK_VERSION" "$operator-operator" "yaook/$operator-operator" \
      --set monitoring.enabled=false \
      --set serviceMonitor.enabled=false \
      --set env[0].name="YAOOK_OP_CLUSTER_DOMAIN",env[0].value="cluster.local";
done

for deploy in $(kubectl get deployments -o jsonpath='{.items[*].metadata.name}'); do   kubectl set env deployment/"$deploy" YAOOK_OP_CLUSTER_DOMAIN=cluster.local; done

kubectl apply -f scripts/full.yaml
