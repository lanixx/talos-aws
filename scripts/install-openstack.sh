#!/bin/bash

export KUBECONFIG="$(pwd)/kubeconfig"
export TALOSCONFIG="$(pwd)/talosconfig"

cd "$(dirname "$0")/.."

kubectl apply -f scripts/full.yaml
