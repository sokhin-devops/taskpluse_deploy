# TaskPluse — Home Lab Plan

*Status: 2026-10-14. This continues `PLAIN.md`; only the infrastructure under the platform changes.*

## Why the plan changed

- The first Vultr account was blocked; the second was closed on 2026-10-14. All cloud VMs and the remaining credit are gone.
- Opening another Vultr account is not an option — the same pattern would very likely be blocked again.
- **Decision:** run TaskPluse on a **spare laptop used as a home lab server**, managed **remotely from the main laptop**, the same way the cloud servers were. Cost: $0. No account that can be closed.
- The complete cloud version (Phases 0–8) is preserved in git: **`git checkout vultr-cloud`**.

## Target layout

```text
MAIN LAPTOP (workstation)                       SPARE LAPTOP (server: lid closed, plugged in, Ethernet)
WSL: Ansible, kubectl, Helm, vault  ───SSH───▶  Ubuntu Server 24.04 LTS (no desktop) + KVM/libvirt
VS Code, Claude Code, git repos                 │
                                                ├── k8s-control-plane   ┐
                                                ├── k8s-worker-1        │ VMs on the private network
                                                ├── k8s-worker-2        │ 10.20.0.0/24 (same range as
                                                └── infra-vm            ┘ the Vultr VPC)
                                                      Nexus, Jenkins, PostgreSQL
                                                │
                                                └── cloudflared ──outbound tunnel──▶ Cloudflare
                                                                                      │
Internet users ──▶ https://taskpluse.sokhin.site (Cloudflare TLS) ────────────────────┘
```

- **No router port is opened.** Public traffic only arrives through the Cloudflare Tunnel, which the lab opens outwards. The home IP is never exposed.
- **The private network keeps `10.20.0.0/24`**, so `private_network_cidr` and every firewall rule built on it stay valid.
- **`registry.sokhin.site`** points at the registry VM's private address. `setup-registry.yml` updates the Cloudflare record itself.
- VM count and sizes are decided from the spare laptop's specs (Step 47). The layout above is the target for 16 GB of RAM or more; with less, Jenkins can run on the workstation in Docker instead.

## What carries over unchanged

| Piece | Status on the home lab |
|---|---|
| `bootstrap.yml` → `setup-server.yml` | Same: admin user, SSH hardening, UFW, updates |
| `setup-kubernetes.yml` | Same: kubeadm 1.36, containerd, Calico VXLAN |
| `cluster/traefik/values.yaml` | Same: DaemonSet on hostPort 80/443 |
| `setup-registry.yml` | Same: Nexus behind Let's Encrypt (DNS-01 needs no open port) |
| Dockerfiles (API, web), Ansible Vault, `scripts/` | Same |

## What is new

| Step | What | Replaces |
|---|---|---|
| H1 | Install Ubuntu Server 24.04 on the spare laptop from USB: SSH on, our public key, Ethernet, keep running with the lid closed | — |
| H2 | Ansible role for the VM host: KVM/libvirt, the private network, VMs created with cloud-init (our SSH key) | `provision-vultr.yml` |
| H3 | `inventory/hosts.yml`: the VMs and their groups, with the addresses we assign | Vultr dynamic inventory |
| H4 | Reach the VMs from the workstation: through the server as SSH jump host and/or a route to `10.20.0.0/24` (decided after Step 47) | Vultr public IPs + firewall |
| H5 | Cloudflare Tunnel for public HTTPS | Public IPs, Vultr firewall rules for Cloudflare |

## Phase status

| Phase | Topic | Status |
|---|---|---|
| 0 | Clean up the old deployment | ✅ done |
| 1–2 | Audit and design | ✅ done |
| 3 | Provision servers | ✅ proven on Vultr → **H1–H4 for the home lab** |
| 4 | Server hardening | ✅ proven on Vultr → re-run on the home lab |
| 5 | Kubernetes cluster | ✅ proven on Vultr → re-run on the home lab |
| 6 | Kubernetes by hand + Traefik | ✅ done (learning complete; Traefik reinstalled on the new cluster) |
| 7 | Docker images | ✅ done (local, independent of any provider) |
| 8 | Nexus registry | 🟡 code committed, partly verified → finish on the home lab (licence decision pending) |
| 9 | Helm chart for TaskPluse | ⬜ |
| 10 | Staging: PostgreSQL, Cloudflare Tunnel, TLS | ⬜ |
| 11–13 | Jenkins CI, push to Nexus, deploy with Helm | ⬜ |
| 14 | Production with approval | ⬜ |
| 15 | Rollback | ⬜ |
| 16 | Database backup and tested restore | ⬜ |
| 17 | Security: Gitleaks, Trivy, dependency scan, RBAC, NetworkPolicy | ⬜ |
| 18 | Monitoring: Prometheus, Grafana, Loki | ⬜ |
| 19 | Scaling: HPA, replicas, PodDisruptionBudget | ⬜ |
| 20 | GitOps evaluation (Argo CD) | ⬜ |

## Open decisions (answered in Step 47)

1. Spare laptop specs (CPU, RAM, disk) → how many VMs and their sizes.
2. Can its disk be wiped for Ubuntu Server?
3. Ethernet available? → network design for H4.

## Honest differences from the cloud

- **One physical machine.** Nodes are VMs, so "high availability" is practised, not real: if the laptop stops, everything stops.
- **Availability depends on the laptop, power and home internet.** Fine for learning and demos.
- **Public access exists only through the Cloudflare Tunnel**, and only while the lab is running.

## Housekeeping

- `~/.kube/taskpluse.conf` on the workstation still points at the closed Vultr cluster. `setup-kubernetes.yml` overwrites it when the new cluster is built.
- The SSH key `~/.ssh/taskpluse_vultr` keeps its name; it is just the passphrase-protected admin key, reused for the home lab.
