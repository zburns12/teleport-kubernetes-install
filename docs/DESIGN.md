# Design

## Goal

Stand up a kubeadm Kubernetes cluster (one control plane, two workers) and deploy a static Nginx site into a namespace, using a non-admin user authenticated by a client certificate issued through the Kubernetes CSR API, with TLS on the site issued by cert-manager.

## Environment

- macOS host (Apple Silicon), three Ubuntu 24.04 arm64 VMs via Multipass.
- Chosen over cloud free tiers so the build has no account dependency and no cost
- VM IPs are DHCP-assigned. The API server is addressed by hostname (`master`) via
  `/etc/hosts` on every node and on the Mac, and `controlPlaneEndpoint` is set at init so the cluster survives a restart. 

## Cluster

- kubeadm with a config file rather than CLI flags, so the build is readable in the repo and reproducible.
- containerd from the Ubuntu 24.04 package with `SystemdCgroup = true`, matching kubelet's default `systemd` cgroup driver. 
- Kubernetes v1.36.4, installed from `pkgs.k8s.io` and pinned with `apt-mark hold`.
- Pod CIDR `10.244.0.0/16`; service CIDR left at the default `10.96.0.0/12`. 

## CNI: Cilium

- Chosen for NetworkPolicy support, the `cilium` CLI's health reporting, and Hubble as an optional observability layer. 
- IPAM mode `kubernetes`: Cilium uses the per-node pod CIDRs that kubeadm allocates from `podSubnet`, so there is one source of truth for pod addressing. 

## Authentication and authorization

**Authentication.** The `deployer` identity is created through the Kubernetes CSR API:

1. A private key and CSR are generated locally with `CN=deployer, O=nginx-team`.
2. The CSR is submitted as a `CertificateSigningRequest` with
   `signerName: kubernetes.io/kube-apiserver-client` and `expirationSeconds: 2592000`.
3. An admin approves it. The controller manager signs it with the cluster CA.
4. The signed certificate is extracted and embedded into a kubeconfig context.

**Authorization.** Authentication grants no permissions. Access comes from a namespaced `Role` in `nginx` bound to the `nginx-team` group. The Role is the smallest set that lets the deployer complete the exercise:

| Resource               | API group         | Verbs | Why                                          |
| ---------------------- | ----------------- | ----- | -------------------------------------------- |
| deployments            | apps              | full  | deploy and update the site                   |
| replicasets            | apps              | read  | `describe deployment` and rollout inspection |
| services, configmaps   | core              | full  | expose the site and hold its content         |
| pods, pods/log, events | core              | read  | monitor and debug                            |
| ingresses              | networking.k8s.io | full  | route external traffic                       |
| certificates           | cert-manager.io   | full  | request TLS for the site                     |

Deliberately excluded: `secrets` (the TLS secret is written by cert-manager and read by the Ingress controller; the deployer never needs it), `pods/exec` (nothing in the exercise requires a shell), `endpoints` (checked as admin during the build; not needed to deploy or monitor), and anything cluster-scoped. `kubectl --context deployer get nodes` and `get pods -n kube-system` both return Forbidden.

## TLS for the site

cert-manager, installed by Helm into its own namespace. The cluster runs a small internal PKI:

1. A `selfSigned` ClusterIssuer, used exactly once to bootstrap.
2. A `Certificate` with `isCA: true` issued by it, producing the `lab-root-ca` secret in the
   `cert-manager` namespace (10-year validity, ECDSA P-256).
3. A `ca` ClusterIssuer (`lab-ca`) that signs from that secret.

The deployer's `Certificate` references `lab-ca` and is issued for `nginx.local` with a 30-day duration and 10-day renewal window. The root's public certificate is trusted once on the Mac, after which the browser shows a valid chain with no warning. The root's private key never leaves the `cert-manager` namespace, which the deployer cannot read.

## Exposure

ingress-nginx as the Ingress controller, exposed as a `NodePort` service with pinned ports (30080 / 30443). The Mac resolves `nginx.local` to the master's IP via `/etc/hosts`. The controller selects the site by `Host` header and terminates TLS with the cert-manager secret. 

The site is `https://nginx.local:30443`

NodePort was chosen because it has no additional components and I was familiar with it. The cost is a non-standard port in the URL. Something like MetalLB in L2 mode would give the controller a stable IP from the VM subnet and is the natural next step.

## Application

Two replicas of `nginxinc/nginx-unprivileged` , with site content from
a ConfigMap mounted read-only. The pod spec meets the Pod Security Standards `restricted` profile: `runAsNonRoot`, `allowPrivilegeEscalation: false`, all capabilities dropped, `RuntimeDefault` seccomp. Requests and a memory limit are set;
readiness and liveness probes hit `/`. Everything in `app/` is applied as `deployer`.

## What went wrong along the way

- `kubeadm init` preflight failed on `net.ipv4.ip_forward`; the sysctl was applied by hand
  and then moved into cloud-init so no node can miss it.
- The Ubuntu containerd package ships without a config file, which means the  `cgroupfs` driver. Caught before init by checking for `SystemdCgroup`.
- The first ConfigMap draft was copied from the ingress-nginx docs (controller tuning in the wrong namespace) rather than site content; pods sat in `FailedMount` until the right one existed.
- The deployer hit `Forbidden` on `endpoints` while verifying the Service. Left out of the Role deliberately. I verified as admin instead.

## Tradeoffs 

**Problems with certificate-based user access as built here**

- No revocation. Kubernetes has no CRL or OCSP for client certificates. A leaked `deployer.key` is valid until it expires. The only remedies are a short lifetime or rotating the cluster CA, which invalidates every identity.
- Identity is only what the certificate says. There is no MFA, no session recording, and the audit trail is limited to API server audit logs keyed on the CN. Nothing ties the certificate to a person or a device.
- Key material lives unencrypted in kubeconfig files on laptops and is trivially copied.
- Issuance is manual. Every new user or renewal requires an admin to approve a CSR. At any scale this is either a bottleneck or gets scripted in a way that removes the review.
- Group membership is baked into the certificate at issue time. Moving someone between teams means a new certificate.

