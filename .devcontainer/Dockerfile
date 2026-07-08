# Dev-Container für LANIXX-HH/talos-aws
#
# Enthält alles, was der Justfile-Deploy-Workflow und die beiden Install-Skripte
# brauchen und wofür es KEIN offizielles devcontainer-Feature gibt:
#   - talosctl : gepinnt auf die Cluster-Version (talos_version in terraform.tfvars)
#   - just     : Task-Runner, den das Repo als Deploy-Entrypoint nutzt (Justfile)
#   - jq       : von scripts/install-openstack.sh verwendet (helm search ... -o json)
#   - openssl  : erzeugt die Yaook-Root-CA in scripts/install-openstack.sh
#   - yaookctl : Troubleshooting-CLI für Yaook-Cluster (z. B. galera force-bootstrap)
#
# terraform, aws-cli, kubectl und helm kommen über devcontainer-Features
# (siehe devcontainer.json). yaookctl wird NICHT per COPY aus einem
# python:3.12-slim-Builder übernommen: die Ubuntu-Basis nutzt dist-packages statt
# site-packages, der pip-Shebang zeigt auf /usr/local/bin/python (fehlt hier) und
# PEP 668 blockt System-pip. Deshalb via pipx in ein isoliertes venv.

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# talosctl muss zur Talos-Version des Clusters passen (terraform.tfvars: talos_version).
# Beim Anheben von talos_version diesen Wert mit anpassen.
ARG TALOSCTL_VERSION=v1.12.9

# System-Pakete: jq + openssl für die Deploy-Skripte, bash-completion als Komfort.
# curl und git sind im Basis-Image bereits vorhanden.
RUN apt-get update \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt-get install -y --no-install-recommends jq openssl bash-completion \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# talosctl – arch-bewusst (amd64 / Apple-Silicon-arm64) und auf TALOSCTL_VERSION gepinnt.
RUN arch="$(dpkg --print-architecture)" \
 && case "$arch" in \
      amd64) tarch="amd64" ;; \
      arm64) tarch="arm64" ;; \
      *) echo "nicht unterstützte Architektur: $arch" >&2; exit 1 ;; \
    esac \
 && curl -fsSL -o /usr/local/bin/talosctl \
      "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-${tarch}" \
 && chmod +x /usr/local/bin/talosctl

# just – Task-Runner (https://github.com/casey/just)
RUN curl --proto '=https' --tlsv1.2 -fsSL https://just.systems/install.sh \
      | bash -s -- --to /usr/local/bin

# ── yaookctl ────────────────────────────────────────────────────────────────
# Für reproduzierbare Builds auf einen Commit/Tag pinnen statt "devel", z. B.:
#   docker/devcontainer build --build-arg YAOOKCTL_REF=<commit-sha>
ARG YAOOKCTL_REF=devel

# Build-Abhängigkeiten für evtl. quell-kompilierte Wheels (cryptography, lxml, …).
# Die meisten Yaook-Deps liefern manylinux-Wheels; dieser Satz ist die Absicherung
# und kann bei Bedarf verschlankt werden. pipx + python3-venv für die Isolation.
RUN apt-get update \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt-get install -y --no-install-recommends \
        pipx python3-venv \
        build-essential libffi-dev libssl-dev libxml2-dev libxslt1-dev \
 && rm -rf /var/lib/apt/lists/*

# yaookctl in ein isoliertes venv installieren; Launcher landet global in
# /usr/local/bin (auf dem PATH für alle User, auch den vscode-User zur Laufzeit).
ENV PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin
RUN pipx install "git+https://gitlab.com/yaook/yaookctl.git@${YAOOKCTL_REF}" \
 && yaookctl --help >/dev/null

# Bash-Completions (optional, schadet nicht)
RUN talosctl completion bash > /etc/bash_completion.d/talosctl 2>/dev/null || true \
 && just --completions bash    > /etc/bash_completion.d/just     2>/dev/null || true \
 && yaookctl --completion bash > /etc/bash_completion.d/yaookctl 2>/dev/null || true
