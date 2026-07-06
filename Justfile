# Justfile für talos-aws – kompletter Deploy-Workflow inkl. Kubelet-TLS-Fix
#
# Voraussetzung: just (https://github.com/casey/just), terraform, aws-cli
# (authentifiziert), kubectl, talosctl, helm, git.
# Im Repo-Root ausführen (gleiches Verzeichnis wie main.tf).
#
#   just            -> kompletter Durchlauf: Terraform, Configs, Cilium,
#                       Kubelet-TLS-Fix, Cleanup, Verify
#   just --list     -> alle verfügbaren Recipes
#   just status     -> Nodes/Pods/CSRs anzeigen, ohne etwas zu verändern
#   just destroy    -> Cluster wieder abbauen

set shell := ["bash", "-c"]

export KUBECONFIG  := justfile_directory() + "/kubeconfig"
export TALOSCONFIG := justfile_directory() + "/talosconfig"

default: deploy

# Kompletter Durchlauf: Terraform, Configs, Cilium, TLS-Fix, Cleanup, Verify
deploy: apply configs cilium fix-metrics-server cleanup-approver verify
    @echo "🎉 Fertig - Cluster läuft, Kubelet-TLS-Kette repariert."


# --- Terraform ---

init: 
    terraform init

plan: init
    terraform plan

apply: init
    terraform apply -auto-approve

# --- Cluster-Zugriff & CNI ---

configs:
    terraform output -raw kubeconfig  > kubeconfig
    terraform output -raw talosconfig > talosconfig
    @echo "✅ kubeconfig und talosconfig geschrieben."

cilium:
    bash scripts/install-cilium.sh
    sleep 15

# --- Kubelet-TLS-Fix (selbstsignierte Serving-Zertifikate statt Approver) ---

fix-metrics-server:
    #!/usr/bin/env bash
    set -euo pipefail
    if kubectl get deployment metrics-server -n kube-system \
        -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q kubelet-insecure-tls; then
        echo "metrics-server hat --kubelet-insecure-tls bereits gesetzt."
    else
        kubectl patch deployment metrics-server -n kube-system --type='json' \
          -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
        kubectl rollout status deployment metrics-server -n kube-system --timeout=120s
    fi

cleanup-approver:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl delete namespace kubelet-serving-cert-approver --ignore-not-found
    pending=$(kubectl get csr --no-headers 2>/dev/null | awk '$5=="Pending"{print $1}' || true)
    if [ -n "$pending" ]; then
        echo "$pending" | xargs -r kubectl delete csr
        echo "Pending CSRs aufgeräumt."
    fi

# --- Kontrolle ---

verify:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl get nodes -o wide
    echo "Warte kurz auf metrics-server..."
    sleep 15
    kubectl top nodes || echo "metrics-server evtl. noch nicht bereit - 'just verify' gleich nochmal ausführen."

status:
    kubectl get nodes -o wide
    kubectl get pods -A
    kubectl get csr

# --- Abbau ---

destroy: 
    #!/usr/bin/env bash
    set -euo pipefail
    lbs=$(kubectl get svc -A --no-headers 2>/dev/null | awk '$3=="LoadBalancer"{print $1"/"$2}' || true)
    if [ -n "$lbs" ]; then
        echo "Lösche LoadBalancer-Services:"
        echo "$lbs" | while IFS=/ read -r ns name; do
            echo "  - $ns/$name"
            kubectl delete svc "$name" -n "$ns"
        done
        echo "Warte 15s, bis AWS die zugehörigen ELBs entfernt hat..."
        sleep 15
    fi
    terraform destroy

clean:
    rm -f kubeconfig talosconfig
