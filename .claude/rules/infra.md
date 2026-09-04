---
paths:
  - "infra/**"
  - "scripts/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/infra_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `infra/` and `scripts/` (OpenTofu, gitops, operations scripts)

Contracts of record: `specs/003-platform-foundation/contracts/gitops-repo.md` and `contracts/network-policy.md`. They also govern edits to the `platform-gitops` repository when it is worked on from this workspace. On conflict, the contracts prevail; amend them first.

## OpenTofu

- A routine `tofu plan` MUST show 0 destroys. Any plan with a destroy stops the work: get the user's explicit approval and record it in the PR before applying.
- Change flow is plan → review → apply; never apply an unreviewed plan. Pin provider versions; state and credentials never enter the repository.
- NSG: 443 ingress is open to Cloudflare IPv4 ranges only; no `0.0.0.0/0` ingress rules. SSH (22) is never publicly exposed — access goes through the cloudflared tunnel only. IMDS v1 stays disabled on instances.
- **Bootstrap exception (while cloudflared is not yet running on the nodes — T013/T014 reimage sessions and the T035–T039 K3s bootstrap window):** the operator may add a temporary NSG ingress rule for 22/tcp from exactly one operator address (`<ip>/32`, never `0.0.0.0/0`) with the OCI CLI, outside OpenTofu — it is never declared under `infra/`. For T013/T014 the rule is removed in the same operator session. For T035–T039 one rule on `nsg-cluster` may stay for the whole window (user decision 2026-09-04, option A) and is removed at the end of T039 once the `ssh-a`/`ssh-b` tunnel hosts work; if the operator address changes, the old rule is removed before a new one is added. Removal is proven by `oci network nsg rules list` showing only the declared rules; a clean `tofu plan` does not prove it, because OpenTofu does not track rules it did not create.

## GitOps (platform-gitops conventions)

- Images by digest: `apps/*/overlays/<env>/kustomization.yaml` `images:` entries carry `newName` + `digest: sha256:...` only — `newTag` is forbidden (validate.yml fails on it). `platform/` images pin `@sha256:...` alongside the tag.
- sync-wave: the single table in `contracts/gitops-repo.md` §sync-wave is the only source of truth. Application `argocd.argoproj.io/sync-wave` annotations must match it; never duplicate wave numbers elsewhere; a new `platform/<component>/` directory requires amending that table first.
- ExternalSecret: `apiVersion: external-secrets.io/v1`; `remoteRef.key` matches `^(platform|dev|prod)/...`; store ↔ location must agree (`overlays/dev` → `vault-dev` + `dev/` keys, `overlays/prod` → `vault-prod` + `prod/`, `secrets/**` → `vault-platform` + `platform/`); `auth.kubernetes.serviceAccountRef` always names `namespace: external-secrets`.
- Per pod exactly 2 ExternalSecrets: `<pod>-env` (runtime) and `<pod>-migrate` (owner DB, PreSync Job only). A Deployment/CronJob `envFrom` referencing `-migrate` is a failure.
- CA mirror (`k8s-data-ca`): `remoteRef.key` in {`pg-main-ca`, `jt-kafka-cluster-ca-cert`} with `remoteRef.property: ca.crt` only — `dataFrom` is forbidden (it would copy `ca.key` into app namespaces).
- Workers-only secret paths (`(dev|prod)/(access|web)/...`) NEVER appear in `apps/**` ExternalSecrets; those values go to Workers Secrets only.
- NetworkPolicy: the allow matrix in `contracts/network-policy.md` is exhaustive — no `allow-all`, and a new path amends the contract first. Every egress `ipBlock` rule carries `ports` plus the 4 `except` entries (IMDS + the three RFC 1918 ranges).

## Bootstrap and operations scripts

- MUST be idempotent: check for existence before creating, and a re-run yields the same end state with no duplicate resources and no error. This includes `platform-backup.sh`, `host-prep.sh`, and `cutover-web.sh` — verify by running twice.
- `platform-backup.sh` reaches Vault only via `kubectl port-forward svc/vault 8200`; NEVER via the public host (`vault.joshuatech.dev`) or a pod IP.
- Scripts read credentials from the environment at run time; they never embed, cache, or write credentials to disk.

## Credentials (hard boundary for agents)

- NEVER put the operator's personal account credentials, the admin kubeconfig, or the `jt-ops` SSH private key into agent environment variables, files, or the repository — in any form, including "temporarily".
- Agent identities are fixed: E2E flows use `e2e@joshuatech.dev`; cluster access uses a short-lived `agent-view` token; OCI access uses `svc-verify` session tokens only. If a task seems to need more, stop and ask the user — do not escalate.

## `jt-ops` key rules

- The `jt-ops` SSH key MUST be a FIDO2 hardware key. If hardware-backed keys are impossible, use a passphrase-protected key loaded with `ssh-add -c` (confirm-on-use prompt) — never an unprotected key.
- SSH connections go through cloudflared (`ssh-a.` / `ssh-b.` tunnel hosts), never a direct public endpoint — except under the bootstrap exception above.
- At the end of every operator session, run `cloudflared access logout`.
