# Kubernetes (kubeadm) + RBAC-scoped Nginx deployment

Take-home for the Teleport Customer Solutions interview. A three-node kubeadm cluster
(one control plane, two workers) running as Multipass VMs on macOS, with a static Nginx
site deployed by a certificate-authenticated user whose access is limited to one namespace.

See `docs/DESIGN.md` for approach and tradeoffs.

## Stack

| Component    | Version                      | Notes                                        |
| ------------ | ---------------------------- | -------------------------------------------- |
| Ubuntu       | 24.04 (Multipass image)      | arm64 on Apple Silicon                       |
| containerd   | Ubuntu 24.04 package (1.7.x) | `SystemdCgroup = true`                       |
| Kubernetes   | v1.36.4                      | kubeadm / kubelet / kubectl, pinned and held |
| Cilium       | chart 1.20.1                 | CNI; kube-proxy left in place                |
| cert-manager | v1.21.1                      | TLS for the Nginx site                       |
| Nginx        | 1.15.1                       | static site                                  |

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

All of this is done as the cluster admin. Kubernetes has no user objects: a user is
whatever identity the API server reads from a certificate signed by the cluster CA.

Create the namespace and the least-privilege Role, bound to the `nginx-team` group:

```bash
kubectl apply -f rbac/namespace.yaml -f rbac/role.yaml -f rbac/roleBinding.yaml
```

Create the `deployer` user via the CSR API. The script generates a key and CSR
(`CN=deployer`, `O=nginx-team`), submits a `CertificateSigningRequest` with the
`kubernetes.io/kube-apiserver-client` signer, approves it, extracts the signed cert,
and adds a `deployer` context to the current kubeconfig:

```bash
./rbac/create_user.sh deployer nginx-team nginx 2592000   # 30-day cert
```

Verify identity and scope:

```bash
kubectl --context deployer auth whoami                    # deployer, groups [nginx-team system:authenticated]
kubectl --context deployer auth can-i --list -n nginx     # exactly the Role's rules
kubectl --context deployer get pods -n kube-system        # Forbidden
kubectl --context deployer get nodes                      # Forbidden
```

Generated key material (`deployer.key`, `.csr`, `.crt`) stays local and is gitignored.

### 6. Ingress controller, cert-manager and the site

#### ingress-nginx (admin)

NodePort, with ports pinned so they survive reinstall:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --version <CHART_VERSION> \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443
kubectl -n ingress-nginx get svc,pods
```

#### cert-manager and issuers (admin)

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --version <CHART_VERSION> \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
kubectl -n cert-manager get pods

kubectl apply -f platform/cert-manager/
kubectl get clusterissuer                              # selfsigned-bootstrap, lab-ca: READY True
kubectl -n cert-manager get certificate lab-root-ca    # READY True
```

A self-signed bootstrap issuer mints one root CA (`lab-root-ca`); the `lab-ca`
ClusterIssuer signs site certificates from it. The root's private key lives only in the
`cert-manager` namespace, which `deployer` cannot read.

#### Trust the root on the Mac (once)

```bash
# master
kubectl -n cert-manager get secret lab-root-ca -o jsonpath='{.data.ca\.crt}' | base64 -d > lab-root-ca.crt
# Mac
multipass transfer master:/home/ubuntu/lab-root-ca.crt .
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain lab-root-ca.crt
echo "$(multipass info master --format csv | tail -n1 | cut -d, -f3) master nginx.local" | sudo tee -a /etc/hosts
```

#### Deploy the site (deployer)

```bash
kubectl --context deployer apply -f app/
kubectl --context deployer get pods,svc,ingress,certificate -n nginx
```

Two `nginx-unprivileged` replicas (non-root, all capabilities dropped, read-only
ConfigMap-mounted content), a ClusterIP Service, a cert-manager `Certificate` issued by
`lab-ca` for `nginx.local`, and an Ingress terminating TLS with that certificate.

#### Verify from the Mac

```bash
curl -v https://nginx.local:30443 2>&1 | grep -E 'issuer|HTTP/'
# issuer: CN=lab-root-ca
# HTTP/2 200
```

Then open `https://nginx.local:30443` in a browser.

## Teardown

```bash
multipass delete master worker-1 worker-2 && multipass purge
```

## AI use

Disclosed per file in `AI_DISCLOSURE.md`, as required by the exercise.

# teleport-kubernetes-install
