#!/usr/bin/env bash
set -euo pipefail

# Installiert Cilium als CNI auf dem Talos-Cluster.
#
# Das isovalent/terraform-aws-talos-Modul setzt network.cni.name = "none" und
# deaktiviert kube-proxy (siehe Befund 3 in README.md) - ohne diesen Schritt
# bleiben alle Nodes nach "terraform apply" dauerhaft NotReady.
#
# Einmalig ausfuehren, NACHDEM "terraform apply" erfolgreich durchgelaufen ist:
#   ./scripts/install-cilium.sh

CILIUM_VERSION="${CILIUM_VERSION:-1.18.0}"

cd "$(dirname "$0")/.."
terraform output -raw kubeconfig > /tmp/kubeconfig
export KUBECONFIG
KUBECONFIG="/tmp/kubeconfig"

command -v helm >/dev/null || { echo "helm ist nicht installiert (https://helm.sh/docs/intro/install/)" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl ist nicht installiert" >&2; exit 1; }

helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
helm repo update cilium >/dev/null

# Werte gemaess offizieller Talos-Anleitung fuer Cilium mit kube-proxy-Replacement
# und KubePrism (localhost:7445): https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium
helm upgrade --install cilium cilium/cilium \
  --version "${CILIUM_VERSION}" \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445
  --set-json 'operator.tolerations=[{"key":"node.cloudprovider.kubernetes.io/uninitialized","value":"true","effect":"NoSchedule"},{"key":"node.kubernetes.io/not-ready","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/control-plane","effect":"NoSchedule"}]'

