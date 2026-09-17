# Joining the worker nodes

Run after Cilium is installed and `kubectl get nodes` shows `master` as Ready.

On master, print a fresh join command (the token from `kubeadm init` expires after 24h):

```bash
kubeadm token create --print-join-command
```

Because `controlPlaneEndpoint` is set, the output points at `master:6443`, which the
workers resolve via the `/etc/hosts` entry added by `infra/launch.sh`.

On each worker, run the printed command with sudo:

```bash
sudo kubeadm join master:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

Back on master:

```bash
kubectl get nodes -o wide
cilium status --wait
```

Expected: three Ready nodes, `cilium` DaemonSet 3/3, `cilium-operator` 2/2.
