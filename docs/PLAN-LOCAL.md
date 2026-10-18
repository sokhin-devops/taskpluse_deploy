# TaskPluse — Local Platform Plan

*Status: 2026-10-18. This continues `PLAIN.md`; only the infrastructure under the platform changes.*

## How we got here

- Both Vultr accounts were closed (the second on 2026-10-14). The complete cloud version — provisioning, hardening, kubeadm cluster, Traefik, Nexus — is preserved as **`git checkout vultr-cloud`**.
- A spare laptop (Dell Latitude 3420, 8 GB RAM) was considered as a home-lab server. 8 GB fits only two small VMs, so it is kept for later (see the last section).
- **Decision: run the platform on the workstation itself** with **kind** (Kubernetes in Docker). The workstation has 40 GB RAM and 20 threads, so a 3-node cluster plus Nexus, Jenkins and PostgreSQL fit comfortably. Cost: $0, nothing that can be closed.

## Why kind, and what it does and doesn't teach

kind runs each Kubernetes node as a Docker container, set up by **kubeadm** — the same tool used on Vultr. The cluster is described in a YAML file in git, so it can be deleted and recreated in minutes.

| Covered on kind | Already proven on Vultr (Phases 3–5, in git) |
|---|---|
| kubectl, Deployments, Services, Ingress, Helm | Creating and hardening servers (Ansible, SSH, UFW) |
| ConfigMaps, Secrets, RBAC, ServiceAccounts, NetworkPolicy (Calico) | Installing a cluster on real machines (kubeadm, containerd, Calico on VMs) |
| Probes, limits, rolling updates, rollback, PDB, node drain | Cloud networking and firewalls |
| HPA with real metrics, multi-node scheduling | |
| Jenkins CI/CD, Nexus, Trivy, Gitleaks, backups, monitoring, Argo CD | |

Day-to-day DevOps work on managed Kubernetes (EKS/GKE/AKS) is the left column; nobody manages nodes there either.

## Target layout

```text
WORKSTATION (Windows 11 + WSL2 + Docker, 40 GB RAM)
│
├── kind cluster "taskpluse"  (cluster/kind/kind-config.yaml)
│   ├── control-plane    (container)
│   ├── worker-1         (container)  ┐ Traefik, TaskPluse staging + production,
│   └── worker-2         (container)  ┘ Calico for NetworkPolicy
│
├── Docker Compose "infra"  (outside the cluster, like separate servers)
│   ├── Nexus        - Docker registry Jenkins pushes to and the cluster pulls from
│   ├── Jenkins      - CI/CD: test, scan, build, push, helm deploy
│   └── PostgreSQL   - the database, outside Kubernetes (safer persistence, simple backups)
│
└── cloudflared  ──outbound tunnel──▶ Cloudflare ──▶ https://taskpluse.sokhin.site (while the PC is on)
```

- **Kubernetes stays the application runtime**; Nexus, Jenkins and PostgreSQL stay outside it, as in the original design.
- **Public access only through a Cloudflare Tunnel** — no router port is opened, the home IP is never exposed.
- **Everything is code in this repo**: the kind config, the Compose file, Helm chart, Jenkinsfiles. Secrets stay in Ansible Vault / Jenkins credentials, never in git.

## What carries over from the cloud version

| Piece | On the local platform |
|---|---|
| Dockerfiles (API, web) | Unchanged |
| `cluster/traefik/values.yaml` | Reused; port mapping adjusted for kind |
| Calico (VXLAN, NetworkPolicy) | Reused in kind (default CNI turned off) |
| Nexus setup (`roles/nexus`) | Logic reused (REST API config, ALLOW_ONCE, push/pull accounts); runs in Compose |
| Ansible Vault, `scripts/create-vault.sh` | Unchanged |
| `bootstrap`, `setup-server`, `setup-kubernetes`, `setup-registry` playbooks | Kept for real servers (the Dell later, or any cloud) |

## Phase status

| Phase | Topic | Status |
|---|---|---|
| 0–2 | Cleanup, audit, design | ✅ done |
| 3–5 | Servers, hardening, kubeadm cluster | ✅ proven on Vultr (tag `vultr-cloud`) |
| 6 | Kubernetes by hand + Traefik | ✅ done |
| 7 | Docker images | ✅ done |
| **L1** | **kind cluster: 3 nodes, Calico, Traefik** | ⬜ next |
| **L2** | **Infra in Compose: Nexus, Jenkins, PostgreSQL** | ⬜ |
| 8 | Nexus registry: push from workstation, pull from cluster | 🟡 role written on Vultr → finish locally (licence decision pending) |
| 9 | Helm chart for TaskPluse | ⬜ |
| 10 | Staging: database, Cloudflare Tunnel, public HTTPS | ⬜ |
| 11–13 | Jenkins CI, push to Nexus, deploy with Helm | ⬜ |
| 14 | Production with approval | ⬜ |
| 15 | Rollback | ⬜ |
| 16 | Database backup and tested restore | ⬜ |
| 17 | Security: Gitleaks, Trivy, dependency scan, RBAC, NetworkPolicy | ⬜ |
| 18 | Monitoring: Prometheus, Grafana, Loki | ⬜ |
| 19 | Scaling: HPA, replicas, PodDisruptionBudget | ⬜ |
| 20 | GitOps evaluation (Argo CD) | ⬜ |

## Honest limits

- **Runs only while the workstation is on.** The public demo URL is down when the PC sleeps.
- **One physical machine.** Node failure is simulated (stop a node container), not real.
- **Resource sharing.** The platform shares the PC with daily work; WSL's memory is capped in `.wslconfig` so Windows stays responsive.

## Later: the Dell as a production server

The Dell Latitude 3420 (i5-1145G7, 8 GB, 512 GB SSD, Ethernet) can become an always-on server running Ubuntu Server and a single-node kubeadm cluster, deployed with the existing playbooks. The same Helm chart and Jenkins pipeline would then deploy "production" to it. Optional, after the pipeline works locally.
