# Kubernetes (kubeadm) + RBAC-scoped Nginx deployment

Take-home for the Teleport Customer Solutions interview. A three-node kubeadm cluster
(one control plane, two workers) running as Multipass VMs on macOS, with a static Nginx
site deployed by a certificate-authenticated user whose access is limited to one namespace.

See `docs/DESIGN.md` for approach and tradeoffs.

## Stack

| Component | Version | Notes |
|---|---|---|
| Ubuntu | 24.04 (Multipass image) | arm64 on Apple Silicon |
| containerd | Ubuntu 24.04 package (1.7.x) | `SystemdCgroup = true` |
| Kubernetes | v1.36.4 | kubeadm / kubelet / kubectl, pinned and held |
| Cilium | chart 1.20.1 | CNI; kube-proxy left in place |
| cert-manager | TODO | TLS for the Nginx site |
| Nginx | TODO | static site |

## Prerequisites (Mac)

- [Multipass](https://multipass.run/) (`brew install multipass`)
- `kubectl` matching the cluster minor (optional; you can run everything from `master`)

## Build

### 1. VMs

```bash
./infra/launch.sh
```

Creates `master`, `worker-1`, `worker-2` with `infra/cloud-init.yaml` applied to each
(kernel modules, sysctls, swap off, containerd with systemd cgroup driver, pinned
kubeadm/kubelet/kubectl). Adds a `master` hosts entry to every node; the script prints
the same line for you to add on the Mac.

### 2. Control plane

```bash
multipass mount . master:/repo
multipass shell master
sudo kubeadm init --config /repo/cluster/kubeadm-config.yaml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes   # NotReady until the CNI is installed
```

### 3. CNI

Still on master:

```bash
/repo/cluster/cilium-install.sh
kubectl get nodes   # master -> Ready
```

### 4. Workers

Follow `cluster/join-workers.md`.

### 5. Namespace, RBAC and user

TODO - see `rbac/`

### 6. cert-manager, Nginx, exposure

TODO - see `platform/` and `app/`

## Teardown

```bash
multipass delete master worker-1 worker-2 && multipass purge
```

## AI use

Disclosed per file in `AI_DISCLOSURE.md`, as required by the exercise.
# teleport-kubernetes-install
