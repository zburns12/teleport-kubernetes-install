# Design

## Goal

Stand up a kubeadm Kubernetes cluster (1 control plane, 2 workers) and deploy a static
Nginx site into a namespace using a non-admin user authenticated by a client certificate
issued through the Kubernetes CSR API, with TLS on the site from cert-manager.

## Environment

- macOS host (Apple Silicon), three Ubuntu 24.04 arm64 VMs via Multipass.
- Chosen over cloud free tiers so the build has no account dependency and no cost, and
  over UTM/Vagrant because Multipass takes cloud-init directly and is scriptable.
- VM IPs are DHCP-assigned. The API server is addressed by hostname (`master`) via
  `/etc/hosts` on every node and the Mac, and `controlPlaneEndpoint` is set at init so
  the cluster survives a VM restart.

## Cluster

- kubeadm with a v1beta4 config file rather than flags, so the build is readable in the repo.
- containerd from the Ubuntu 24.04 package with `SystemdCgroup = true`, matching kubelet's
  default `systemd` cgroup driver. Chosen over the upstream tarball for reproducibility;
  tradeoff is an older (1.7.x) containerd.
- Kubernetes v1.36.4, pinned with `apt-mark hold`.
- Pod CIDR `10.244.0.0/16`; service CIDR left at the default `10.96.0.0/12`.

## CNI: Cilium

- Chosen for NetworkPolicy support, the `cilium` CLI's health reporting, and Hubble as an
  optional observability layer. Calico would have been equally valid.
- kube-proxy retained. Cilium's kube-proxy replacement was deliberately left out of this
  build to limit surface area; it is a documented follow-up.
- Operator runs the default 2 replicas with anti-affinity, so it shows 1/2 until the first
  worker joins.
- IPAM mode kubernetes so Cilium uses the per-node CIDRs kubeadm allocates from podSubnet; single source of truth for pod addressing.

## Authentication and authorization

TODO - CSR flow, signer, Role/RoleBinding scope, what the user can and cannot do.

## TLS for the site

TODO - cert-manager issuer choice (self-signed / CA for a local cluster; why not Let's Encrypt here).

## Exposure

TODO - MetalLB L2 vs NodePort; how the browser reaches it.

## Tradeoffs and what I would change for production

- Client-certificate kubeconfigs cannot be revoked short of rotating the cluster CA.
- Identity is only the certificate CN; no MFA, no session recording, audit trail limited
  to API server audit logs keyed on the CN.
- Certificates and keys live unencrypted on user laptops.
- Single control plane; etcd is not backed up.
- TODO: expand after RBAC work is done.
