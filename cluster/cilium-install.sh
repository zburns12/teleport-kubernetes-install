#!/usr/bin/env bash
# Install Cilium as the CNI. Run on master after `kubeadm init` and the kubeconfig copy.
# kube-proxy is left in place; Cilium's kube-proxy replacement is a documented
# follow-up (see docs/DESIGN.md), not part of this build.
set -euo pipefail

CILIUM_CHART_VERSION="1.20.1"
POD_CIDR="10.244.0.0/16"

# --- Helm ---
# Official script: https://helm.sh/docs/intro/install/
# curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION=v3.x.y bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
# --- Cilium ---
# TODO(zach): reconcile with the exact command you ran. If you installed without
# the ipam setting below, Cilium is using its own 10.0.0.0/8 cluster pool and
# ignoring kubeadm's podSubnet. Either add it via `helm upgrade --reuse-values`
# or change the CIDR stated in docs/DESIGN.md so the two agree.
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium \
  --version "1.20.1" \
  --namespace kube-system \
  --set ipam.mode=kubernetes

# --- Cilium CLI (validation / status) ---
CILIUM_CLI_VERSION="$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)"
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check "cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"
sudo tar xzvfC "cilium-linux-${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-linux-${CLI_ARCH}.tar.gz"{,.sha256sum}

cilium status --wait
