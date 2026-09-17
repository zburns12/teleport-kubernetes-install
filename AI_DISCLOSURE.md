# AI Use Disclosure

Every file created or modified with AI assistance is listed below with the degree of assistance. 

I used Claude for this assignment. I ran all commands myself and used the model as a guide, reviewer, and to generate boilerplate. All cluster work was performed by me on my own machine.

Degree scale:
- **Generated**: AI wrote the file and I reviewed and edited
- **Assisted**: I wrote the file and AI provided boilerplate or suggested corrections
- **None**

| File                          | Degree    | Notes                                                                                                           |
| ----------------------------- | --------- | --------------------------------------------------------------------------------------------------------------- |
| `.gitignore`                  | None      |                                                                                                                 |
| `README.md`                   | Assisted  | AI ensured I captured all steps clearly                                                                         |
| `AI_DISCLOSURE.md`            | None      |                                                                                                                 |
| `infra/cloud-init.yaml`       | Generated | Manual node preparation steps.                                                                                  |
| `infra/launch.sh`             | Assisted  | Multipass commands were AI. VM names, sizing, and approach chosen by me.                                        |
| `cluster/kubeadm-config.yaml` | Generated | AI proposed using a config file. I chose the CIDR and hostname convention.                                      |
| `cluster/cilium-install.sh`   | Assisted  | Commands follow the Cilium install docs which I ran manually. AI suggested pinning and the IPAM CIDR alignment. |
| `cluster/join-workers.md`     | Generated | Documents the join process I performed; operator 1/2 note came from a live debugging exchange.                  |
| `rbac/*`                      | Assisted  | AI provided boilerplate for manifests and suggested corrections                                                 |
| `app/*`                       | Assisted  | AI provided boilerplate for manifests and suggested corrections                                                 |
| `platform/*`                  | Assisted  | AI provided corrections to documentation templates                                                              |
| `docs/DESIGN.md`              | Assisted  | AI provided a template to ensure I filled in all design choices                                                 |

