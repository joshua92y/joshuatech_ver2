# Boundary: K8s security

## Purpose
Find cluster- and platform-level security gaps in a Kubernetes/GitOps design before anything is applied — the parts the generic security boundary does not cover.

## Checklist
- Network boundary: only Cloudflare-proxied 443 reaches the origin; no public SSH/API ports; intra-cluster rules are explicit (NSG/security list); Authenticated Origin Pulls or equivalent prevents bypassing the edge.
- Access policies: every admin surface (Argo CD, Vault, Traefik dashboard, Django admin, Kibana) sits behind an identity policy; machine endpoints accept only service tokens; AUD tags are per application and validated by the workload.
- Namespaces and policies: each namespace has Pod Security Admission labels, default-deny NetworkPolicy, ResourceQuota/LimitRange; cross-namespace access is enumerated.
- NetworkPolicy matrix: the policy manifests match the documented traffic matrix exactly — no flow present in one and missing from the other.
- PSA level changes: any change to a namespace's Pod Security Admission level — upgrade and downgrade alike — is a review item, never a silent edit.
- Node identity: instance principal / metadata service (IMDS, 169.254.169.254) is blocked for every namespace except `vault`; IMDS v1 disabled; dynamic groups scoped to specific instances and keys.
- Secrets flow: no secret values in either repository or in tfstate without protection; ExternalSecret paths follow the convention and each resolves through one of the five declared stores; rotation and revocation paths stated.
- Vault: policies are least-privilege per consumer; every auth role carries an audience, bound namespaces, and an explicit TTL; root token revoked.
- GitOps blast radius: AppProjects restrict sourceRepos/destinations/cluster resources; `default` project neutralized; stateful/platform apps use Prune=confirm and Delete=confirm; CRD deletion cannot cascade into data loss.
- Image references: manifests reference images by digest (`@sha256`), never by mutable tag.
- Workload hardening: non-root containers, no privileged pods, host paths limited to declared storage, `automountServiceAccountToken` off where unused, RBAC least privilege for operators.
- Agent credential scope: kubectl only via a short-lived `agent-view` (+`agent-view-extra`) token kubeconfig, plus `pods/portforward` only in the `vault`, `data`, and `identity` namespaces; the admin kubeconfig and the operator's personal credentials (including personal OCI credentials) are forbidden — OCI queries use the read-only `svc-verify` session profile only.
- No public hostnames inside the cluster: in-cluster calls use service DNS only (JWKS via `http://authentik-server.identity.svc:9000/application/o/<pod>/jwks/`; only `iss` stays a public URL) — the only exceptions are the two `auth.joshuatech.dev` OIDC discovery calls by Argo CD and Vault (FR-046).
- OpenFGA: a single instance with one global preshared key serves every environment — dev and prod are separated by store only, with no env isolation; this is the risk accepted in ADR 0006, and the SP-2 `openfga-dev` split stays an open review item.
- Data plane: database roles without BYPASSRLS/SUPERUSER for apps, migrations separated from runtime credentials, broker users scoped by ACL, backups encrypted in transit and stored outside the cluster.
- Supply chain: Helm charts and operators pinned to versions/digests, attestations for own images, Renovate/SHA pins for actions; upgrade windows defined for the control plane and ingress.

## Output format
`| 항목 | 상태 | 비고 |` — one row per checklist line, 상태 ∈ ✅/⚠️/❌/—.
`### Findings` — for each ⚠️/❌: severity (high/medium/low), what, where (spec/plan/tasks/contracts section), concrete fix.
