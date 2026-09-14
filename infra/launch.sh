#!/usr/bin/env bash
# Create the three Multipass VMs and add the control-plane hosts entry to each.
# Run from the repo root on the Mac.
set -euo pipefail

IMAGE="24.04"
CLOUD_INIT="infra/cloud-init.yaml"

multipass launch "$IMAGE" --name master   --cpus 2 --memory 4G --disk 20G --cloud-init "$CLOUD_INIT"
multipass launch "$IMAGE" --name worker-1 --cpus 2 --memory 3G --disk 20G --cloud-init "$CLOUD_INIT"
multipass launch "$IMAGE" --name worker-2 --cpus 2 --memory 3G --disk 20G --cloud-init "$CLOUD_INIT"

# Multipass IPs are DHCP-assigned. Resolve "master" by name inside the cluster
# so kubeadm's controlPlaneEndpoint survives an IP change after stop/start.
MASTER_IP="$(multipass info master --format csv | tail -n1 | cut -d, -f3)"
echo "master IP: ${MASTER_IP}"

for node in master worker-1 worker-2; do
  multipass exec "$node" -- sudo bash -c "grep -q ' master$' /etc/hosts || echo '${MASTER_IP} master' >> /etc/hosts"
done

echo
echo "Add the same entry to your Mac so kubectl and the browser resolve 'master':"
echo "  echo '${MASTER_IP} master' | sudo tee -a /etc/hosts"
echo
multipass list
