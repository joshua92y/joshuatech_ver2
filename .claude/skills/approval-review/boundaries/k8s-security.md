# Boundary: K8s security

## Purpose
Find cluster- and platform-level security gaps in a Kubernetes/GitOps design before anything is applied — the parts the generic security boundary does not cover.

## Checklist
- Network boundary: only Cloudflare-proxied 443 reaches the origin; no public SSH/API ports; intra-cluster rules are explicit (NSG/security list); Authenticated Origin Pulls or equivalent prevents bypassing the edge.
- Access policies: every admin surface (Argo CD, Vault, Traefik dashboard, Django admin, Kibana) sits behind an identity policy; machine endpoints accept only service tokens; AUD tags are per application and validated by the workload.
- Namespaces and policies: each namespace has Pod Security Admission labels, default-deny NetworkPolicy, ResourceQuota/LimitRange; cross-namespace access is enumerated.
- Node identity: instance principal / metadata service (169.254.169.254) is reachable only by the workloads that need it; IMDS v1 disabled; dynamic groups scoped to specific instances and keys.
- Secrets flow: no secret values in either repository or in tfstate without protection; ExternalSecret paths follow the convention; rotation and revocation paths stated; Vault auth roles carry audience and bound namespaces; root token revoked.
- GitOps blast radius: AppProjects restrict sourceRepos/destinations/cluster resources; `default` project neutralized; stateful/platform apps use Prune=confirm and Delete=confirm; CRD deletion cannot cascade into data loss; images referenced by digest only.
- Workload hardening: non-root containers, no privileged pods, host paths limited to declared storage, `automountServiceAccountToken` off where unused, RBAC least privilege for operators.
- Data plane: database roles without BYPASSRLS/SUPERUSER for apps, migrations separated from runtime credentials, broker users scoped by ACL, backups encrypted in transit and stored outside the cluster.
- Supply chain: Helm charts and operators pinned to versions/digests, attestations for own images, Renovate/SHA pins for actions; upgrade windows defined for the control plane and ingress.

## Output format
`| 항목 | 상태 | 비고 |` — one row per checklist line, 상태 ∈ ✅/⚠️/❌/—.
`### Findings` — for each ⚠️/❌: severity (high/medium/low), what, where (spec/plan/tasks/contracts section), concrete fix.
