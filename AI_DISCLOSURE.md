# AI Use Disclosure

Per the exercise requirements, every file created or modified with AI assistance is listed
below with the degree of assistance. Tool used: Claude (Anthropic), in a chat session where
I ran all commands myself and used the model as a guide, reviewer, and to generate
boilerplate. All cluster work (VM creation, package installs, `kubeadm init`/`join`, Cilium
install, debugging) was performed by me on my own machine.

Degree scale:
- **Generated**: AI wrote the file; I reviewed and edited.
- **Assisted**: I wrote it; AI suggested structure, commands, or corrections.
- **None**: no AI involvement.

| File | Degree | Notes |
|---|---|---|
| `.gitignore` | Generated | |
| `README.md` | Generated | Structure and initial content; I filled in TODO sections and verified every command against what I ran. |
| `AI_DISCLOSURE.md` | Generated | Template; contents are mine. |
| `infra/cloud-init.yaml` | Generated | Consolidates the manual node-prep steps I performed following the Kubernetes "Container Runtimes" and "Installing kubeadm" docs. Package version pin filled in by me. |
| `infra/launch.sh` | Generated | Multipass commands were AI-provided; VM names, sizing, and hosts-entry approach chosen by me. |
| `cluster/kubeadm-config.yaml` | Generated | AI proposed using a config file and the `controlPlaneEndpoint` / `podSubnet` values; I chose the CIDR and hostname convention. |
| `cluster/cilium-install.sh` | Assisted | Commands follow the Cilium kubeadm install docs, which I ran manually; AI suggested pinning and the IPAM CIDR alignment. |
| `cluster/join-workers.md` | Generated | Documents the join process I performed; operator 1/2 note came from a live debugging exchange. |
| `rbac/*` | TODO | |
| `app/*` | TODO | |
| `platform/*` | TODO | |
| `docs/DESIGN.md` | TODO | |

Decisions I made without AI: TODO (e.g. node naming to match the assignment wording,
choosing Cilium, keeping kube-proxy, apt containerd over upstream tarball).

Decisions where AI changed my mind: TODO (e.g. using a kubeadm config file rather than
flags; not hand-obscuring AI involvement in the repo layout).
