# vp-s4-storage

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)

Validated Patterns chart for non-production S4 object storage (dev/demo) with External Secrets and bucket provisioning. For production S3 on OpenShift, use openshift-data-foundations (ODF).

Wraps the [S4](https://github.com/rh-aiservices-bu/s4) Helm chart with External Secrets for deployment credentials and imperative Jobs to provision S3 buckets.

> **Not for production.** This chart deploys [S4](https://github.com/rh-aiservices-bu/s4) for development, test, and demonstration. It is not intended for production S3 object storage. For production S3 workloads on OpenShift, use the Validated Patterns **[openshift-data-foundations](https://github.com/validatedpatterns/openshift-data-foundations-chart)** chart ([ODF](https://www.redhat.com/en/technologies/cloud-computing/openshift-data-foundation) on the VP catalog: `chart: openshift-data-foundations` from [charts.validatedpatterns.io](https://charts.validatedpatterns.io)).

Defaults assume an OpenShift cluster: OpenShift Route for the Web UI (Ingress disabled), cluster-default StorageClass for PVCs, pinned S4 image tag, and restricted pod security contexts compatible with the `restricted-v2` SCC.

## Bucket provisioning

Bucket create/destroy logic is shipped as an Ansible playbook in a ConfigMap (`playbooks/s4-buckets.yml`), mounted into the [utility-container](https://quay.io/validatedpatterns/utility-container) (ansible + `amazon.aws`). Default variables live in `vars/defaults.yml` on the mount (ConfigMap key `vars.defaults.yml`); the Job and CronJob pass `s4Role.buckets`, **`s4-credentials`**, and optional `s4Role.destroy` at runtime.

The playbook and variable model were adapted from [eduffy-redhat/s4-role](https://github.com/eduffy-redhat/s4-role). **Credit to Evan Duffy (Red Hat)** for the original Ansible role and approach to managing buckets on an S4 endpoint.

## Secrets (Validated Patterns)

S4 has two access paths, stored in **two Vault secrets** and merged into **one Kubernetes Secret** for the upstream `s4` subchart (no subchart changes):

| Access path | Keys | Vault secret (example) |
|-------------|------|------------------------|
| **Web UI** | `UI_USERNAME`, `UI_PASSWORD` [, `JWT_SECRET`] | `s4-ui-credentials` |
| **S3 API** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | `s4-api-credentials` |

External Secrets Operator uses **one** `ExternalSecret` (`s4Credentials.secretName`) with two `dataFrom.extract` entries (UI and API Vault paths). That avoids `creationPolicy: Merge`, which fails if the target Secret does not exist yet when both resources reconcile in parallel. The resulting secret is passed to the unmodified `s4` subchart via `s4.s3.existingSecret` and is used by bucket Jobs. The API Vault path is the RGW identity for the endpoint, provisioning, and application consumers.

Default examples use `s4admin` for the UI user and S3 access key id; the UI password and API secret key are **generated** (`advancedPolicy`).

Copy `examples/secrets/values-secret.v2.yaml` into your pattern `common/examples/secrets/` and run your pattern secrets tooling (e.g. `./scripts/make-secrets.sh`). Then point the chart at the Vault paths with a values overlay like `examples/chart-secret-values.yaml`.

### `examples/secrets/values-secret.v2.yaml`

```yaml
# NEVER COMMIT REAL SECRETS TO GIT
#
# Validated Patterns secrets example for vp-s4-storage.
# Use from your pattern repo with the secrets tooling, e.g.:
#   ./scripts/make-secrets.sh -f common/examples/secrets/values-secret.v2.yaml
#
# Two Vault secrets (Web UI vs S3 API) merge into Kubernetes Secret s4-credentials.
# Wire Vault paths into the chart via examples/chart-secret-values.yaml.

version: "2.0"
backingStore: vault

vaultPolicies:
  basicPolicy: |
    length=10
    rule "charset" { charset = "abcdefghijklmnopqrstuvwxyz" min-chars = 1 }
    rule "charset" { charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" min-chars = 1 }
    rule "charset" { charset = "0123456789" min-chars = 1 }

  advancedPolicy: |
    length=20
    rule "charset" { charset = "abcdefghijklmnopqrstuvwxyz" min-chars = 1 }
    rule "charset" { charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" min-chars = 1 }
    rule "charset" { charset = "0123456789" min-chars = 1 }
    rule "charset" { charset = "!@#$%^&*" min-chars = 1 }

secrets:
  - name: s4-ui-credentials
    vaultPrefixes:
      - global
    fields:
      - name: UI_USERNAME
        value: s4admin
        onMissingValue: error
      - name: UI_PASSWORD
        onMissingValue: generate
        override: true
        vaultPolicy: advancedPolicy

  - name: s4-api-credentials
    vaultPrefixes:
      - global
    fields:
      - name: AWS_ACCESS_KEY_ID
        value: s4admin
        onMissingValue: error
      - name: AWS_SECRET_ACCESS_KEY
        onMissingValue: generate
        override: true
        vaultPolicy: advancedPolicy

```

### `examples/chart-secret-values.yaml`

```yaml
# Overlay for vp-s4-storage after running pattern secrets tooling.
# Adjust vaultKey paths to match your hub/site prefix (global, cluster, etc.).
#
#   secret/data/global/s4-ui-credentials
#   secret/data/global/s4-api-credentials

s4UICredentials:
  vaultKey: secret/data/global/s4-ui-credentials

s4APICredentials:
  vaultKey: secret/data/global/s4-api-credentials

```

## Validated Patterns clusterGroup

When this chart is published to [charts.validatedpatterns.io](https://charts.validatedpatterns.io), add a namespace and Argo CD application under `clusterGroup` in your hub or site values (same style as other `vp-*` catalog charts):

### `examples/clustergroup-application.yaml`

```yaml
# Example clusterGroup fragment for a Validated Patterns hub (or site) values file.
# Assumes vp-s4-storage is published on https://charts.validatedpatterns.io
# (same catalog as vp-rbac, aap-config, vp-stakater-reloader, etc.).
#
# Merge into values-global.yaml / values-hub.yaml under clusterGroup:.
# Run secrets tooling first (see examples/secrets/values-secret.v2.yaml).

clusterGroup:
  namespaces:
    - s4-storage

  # argoProject must already be listed in clusterGroup.argoProjects
  argoProjects:
    - hub

  applications:
    vp-s4-storage:
      name: vp-s4-storage
      namespace: vp-s4-storage
      argoProject: hub
      chart: vp-s4-storage
      chartVersion: 0.2.*
      overrides:
        # Vault paths from examples/secrets/values-secret.v2.yaml (adjust prefix as needed)
        - name: s4UICredentials.vaultKey
          value: secret/data/global/s4-ui-credentials
        - name: s4APICredentials.vaultKey
          value: secret/data/global/s4-api-credentials
        # Bucket names for the imperative Job/CronJob playbook
        - name: s4Role.buckets[0]
          value: my-app-data
        - name: s4Role.buckets[1]
          value: my-app-logs
        # vp-rbac Role/RoleBinding namespace must match the Argo CD app namespace
        - name: vp-rbac.serviceAccounts.vp-s4-storage-sa.namespace
          value: vp-s4-storage
        - name: vp-rbac.roles.external-secrets-validator.namespace
          value: vp-s4-storage
        # ConsoleLink is enabled by default; href uses global.localClusterDomain from values-global.yaml
        # from values-global.yaml (same as clustergroup Argo CD ConsoleLinks). Optional overrides:
        # - name: consoleLink.href
        #   value: https://s4.apps.mycluster.example.com
        # - name: s4.route.host
        #   value: s4.apps.mycluster.example.com
        # Optional Route hostnames (both Routes enabled by default; see examples/clustergroup-route-overrides.yaml)
        # - name: s4.route.host
        #   value: s4.apps.mycluster.example.com
        # - name: s4.route.s3Api.host
        #   value: s3-s4.apps.mycluster.example.com

```

Argo CD pulls `chart: vp-s4-storage` and `chartVersion: 0.1.*` from the Validated Patterns Helm repo (no `repoURL` required unless you override the default catalog URL). Use `overrides` for Vault keys, bucket lists, and optional Route hostnames. Ensure the `argoProject` you reference is listed in `clusterGroup.argoProjects`.

## Configuring OpenShift Routes

Routes are rendered by the upstream `s4` subchart (`charts/s4/templates/route.yaml` and `route-s3.yaml`). This wrapper passes settings under `s4.route.*` in Helm values or Argo CD `overrides`.

### Helm values file

Full examples (uncomment the scenario you need):

```yaml
# Helm values examples for OpenShift Routes (s4 subchart keys under s4.route.*)
# Use with: helm install ... -f examples/route-values.yaml
# Or merge selected keys into a pattern values overlay / clusterGroup overrides.

# -----------------------------------------------------------------------------
# 1) Default — Web UI + S3 API Routes, cluster-assigned FQDNs (chart defaults)
# -----------------------------------------------------------------------------
# s4:
#   route:
#     enabled: true
#     host: ""
#     annotations:
#       haproxy.router.openshift.io/timeout: 600s
#     s3Api:
#       enabled: true
#       host: ""
#       annotations:
#         haproxy.router.openshift.io/timeout: 600s
#       tls:
#         termination: edge
#         insecureEdgeTerminationPolicy: Allow  # HTTP :80 and HTTPS :443

# -----------------------------------------------------------------------------
# 2) Web UI — custom FQDN (DNS must point at the cluster ingress/router)
# -----------------------------------------------------------------------------
# s4:
#   route:
#     enabled: true
#     host: s4.apps.mycluster.example.com
#     tls:
#       termination: edge
#       insecureEdgeTerminationPolicy: Redirect

# -----------------------------------------------------------------------------
# 3) Web UI + S3 API — custom FQDNs on both Routes
# -----------------------------------------------------------------------------
# s4:
#   route:
#     enabled: true
#     host: s4.apps.mycluster.example.com
#     s3Api:
#       enabled: true
#       host: s3-s4.apps.mycluster.example.com
#       annotations:
#         haproxy.router.openshift.io/timeout: 600s
#       tls:
#         termination: edge
#         insecureEdgeTerminationPolicy: Allow  # or Redirect for HTTPS-only

# -----------------------------------------------------------------------------
# 4) S3 API internal only (Web UI Route still public)
# -----------------------------------------------------------------------------
# s4:
#   route:
#     enabled: true
#     s3Api:
#       enabled: false

# -----------------------------------------------------------------------------
# 5) Disable Routes (Ingress or in-cluster / port-forward only)
# -----------------------------------------------------------------------------
# s4:
#   route:
#     enabled: false
#   ingress:
#     enabled: true
#     className: openshift-default
#     hosts:
#       - host: s4.apps.mycluster.example.com
#         paths:
#           - path: /
#             pathType: Prefix

```

### clusterGroup overrides

Copy override blocks into `clusterGroup.applications.vp-s4-storage.overrides`:

```yaml
# clusterGroup overrides only — merge into clusterGroup.applications.vp-s4-storage.overrides
# Chart defaults enable both Web UI and S3 API Routes (cluster-assigned FQDNs).
#
# Argo CD override names use dotted Helm value paths. Escape dots in annotation keys
# with a backslash in the override name.

# --- Defaults: no overrides (both Routes enabled, auto hostname) ---

# --- Web UI: pinned FQDN ---
overrides_web_ui_host:
  - name: s4.route.host
    value: s4.apps.mycluster.example.com

# --- S3 API: pinned FQDN ---
overrides_s3_api_host:
  - name: s4.route.s3Api.host
    value: s3-s4.apps.mycluster.example.com

# --- Web UI + S3 API: pinned FQDNs on both ---
overrides_web_ui_and_s3_api_hosts:
  - name: s4.route.host
    value: s4.apps.mycluster.example.com
  - name: s4.route.s3Api.host
    value: s3-s4.apps.mycluster.example.com

# --- Web UI: upload timeout annotation ---
overrides_web_ui_annotation:
  - name: s4.route.annotations.haproxy\.router\.openshift\.io/timeout
    value: 600s

# --- S3 API Route off (in-cluster Service only; Web UI Route unchanged) ---
overrides_s3_api_internal_only:
  - name: s4.route.s3Api.enabled
    value: "false"

# --- All OpenShift Routes off ---
overrides_disable_routes:
  - name: s4.route.enabled
    value: "false"

```

Typical override names:

| Goal | Override |
|------|----------|
| Custom Web UI FQDN | `s4.route.host` |
| Router annotation | `s4.route.annotations.haproxy\.router\.openshift\.io/timeout` |
| Custom S3 API FQDN | `s4.route.s3Api.host` |
| Disable S3 API Route | `s4.route.s3Api.enabled: "false"` |
| No Routes | `s4.route.enabled: "false"` |

Rendered resources use the release namespace (e.g. `s4-storage`). Two Routes are created by default: Web UI (`web-ui`, port 5000) and S3 API (`s3-api`, port 7480, object name suffix `-api`).

## Routes and FQDNs (Web UI vs S3 consumers)

OpenShift defaults expose both the **Web UI** and **S3 API** on separate edge-terminated Routes (`s4.route.enabled` and `s4.route.s3Api.enabled`, both `true`). Each gets its own FQDN unless you set `s4.route.host` or `s4.route.s3Api.host`.

### Web UI (human / admin browser access)

| Setting | Behavior |
|---------|----------|
| `s4.route.host` empty | OpenShift assigns a predictable hostname (see below). |
| `s4.route.host` set | Route uses that FQDN; DNS must resolve to the cluster ingress/router. |
| TLS | Edge termination (HTTPS at the router; HTTP to the pod). |

### Predictable FQDNs when `host` is empty

Yes. If you do not set `s4.route.host` or `s4.route.s3Api.host`, OpenShift fills `spec.host` on each Route using the cluster ingress domain. The pattern is:

```text
<route.metadata.name>-<namespace>.<ingress-domain>
```

**Step 1 — Route object names (from Helm, before apply)**

The `s4` subchart names routes from `s4.fullname`:

| Route | `metadata.name` |
|-------|-----------------|
| Web UI | `{s4.fullname}` |
| S3 API | `{s4.fullname}-api` |

`{s4.fullname}` is computed as:

- `s4.fullnameOverride` if set, else
- `Release.Name` if it **contains** the substring `s4`, else
- `{Release.Name}-s4`

For a typical Validated Patterns app (`name: vp-s4-storage`, Argo CD release `vp-s4-storage`), `Release.Name` contains `s4`, so:

| Resource | Name |
|----------|------|
| Web UI Route | `vp-s4-storage` |
| S3 API Route | `vp-s4-storage-api` |
| Service (in-cluster S3) | `vp-s4-storage` |

If your release name does not contain `s4` (e.g. release `storage`), use `storage-s4` and `storage-s4-api` instead.

**Step 2 — Ingress domain (cluster constant)**

```bash
oc get ingresses.config cluster -o jsonpath='{.status.domain}{"\n"}'
```

Example output: `apps.ocp4.example.com` (varies per cluster; set by install or `Ingress.config.openshift.io`).

**Step 3 — Assemble the FQDN**

With namespace `s4-storage` and ingress domain `apps.ocp4.example.com`:

```text
Web UI:  vp-s4-storage-s4-storage.apps.ocp4.example.com
S3 API:  vp-s4-storage-api-s4-storage.apps.ocp4.example.com
```

Template:

```text
https://{route-name}-{namespace}.{ingress-domain}    # Web UI or S3 Route (edge TLS)
http://{s4.fullname}.{namespace}.svc:7480          # in-cluster S3 only
```

After deploy, confirm:

```bash
INGRESS_DOMAIN=$(oc get ingresses.config cluster -o jsonpath='{.status.domain}')
NS=s4-storage
echo "Web UI:  vp-s4-storage-${NS}.${INGRESS_DOMAIN}"
echo "S3 API:  vp-s4-storage-api-${NS}.${INGRESS_DOMAIN}"

oc get route -n "${NS}" -l app.kubernetes.io/name=s4 -o custom-columns=NAME:.metadata.name,HOST:.spec.host
```

Log in to the Web UI with **`s4-credentials`** (`UI_USERNAME` / `UI_PASSWORD`). Do not use the Web UI Route URL as an S3 endpoint.

### S3 / bucket access (applications and automation)

Use the S3 keys in **`s4-credentials`** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`), region `us-east-1`. The same secret backs the RGW process, bucket Jobs (`s4Role.buckets`), and application clients.

**In-cluster** (typical for pods on the same cluster):

```text
http://vp-s4-storage.s4-storage.svc:7480
```

```bash
export AWS_ACCESS_KEY_ID=$(oc get secret s4-credentials -n s4-storage -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
export AWS_SECRET_ACCESS_KEY=$(oc get secret s4-credentials -n s4-storage -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
aws --endpoint-url http://vp-s4-storage.s4-storage.svc:7480 s3 ls
```

**Outside the cluster** (default chart also creates an S3 API Route):

The S3 API Route defaults to `s4.route.s3Api.tls.insecureEdgeTerminationPolicy: Allow`, so clients can use **HTTP on port 80** or **HTTPS on port 443** (edge termination). The Web UI Route still redirects HTTP to HTTPS (`Redirect`).

```bash
S3_HOST=$(oc get route vp-s4-storage-api -n s4-storage -o jsonpath='{.spec.host}')
aws --endpoint-url "http://${S3_HOST}" s3 ls
# or: aws --endpoint-url "https://${S3_HOST}" s3 ls
```

Or set `s4.route.s3Api.host` to a stable name (e.g. `s3-s4.apps.mycluster.example.com`) in values or clusterGroup overrides. Set `s4.route.s3Api.tls.insecureEdgeTerminationPolicy: Redirect` to force HTTPS only. Restrict access with network policy; the S3 Route exposes the API outside the cluster.

## Notable changes

### Argo CD sync wave ordering

Default `s4.commonAnnotations` sets `argocd.argoproj.io/sync-wave: "2"` on S4 subchart resources (Deployment, Service, PVC, and related objects). Umbrella-chart resources keep their existing waves: ExternalSecrets and the validation Job at **1**, bucket ConfigMap at **2**, bootstrap Job at **3**, CronJob at **5**. That ensures credentials exist before the S4 Deployment starts and the bootstrap Job still runs after the workload is up.

### S3 API Route HTTP (port 80)

Default `s4.route.s3Api.tls.insecureEdgeTerminationPolicy` is `Allow` so the S3 API Route serves HTTP on port 80 as well as HTTPS on port 443. The Web UI Route remains `Redirect` (HTTP to HTTPS).

### OpenShift ConsoleLink (Web UI)

When the Web UI Route is enabled (`consoleLink.enabled` defaults to `true`), the chart creates a cluster `ConsoleLink` in the console **Application menu** (`consoleLink.section: Storage`), matching the Validated Patterns clustergroup style used for Argo CD (`common/clustergroup/templates/plumbing/argocd.yaml`) and Vault ConsoleLinks. The `spec.href` URL is `s4.route.host` when set, else `https://{route}-{namespace}.{ingress-domain}` with `ingress-domain` from `coalesce(consoleLink.ingressDomain, global.localClusterDomain)` — `global.localClusterDomain` is set by the pattern framework in `values-global.yaml`. Override with `consoleLink.href` if needed. Set `consoleLink.enabled: false` to disable. The icon is the 64×64 PNG from [rh-aiservices-bu/s4](https://github.com/rh-aiservices-bu/s4) (`assets/s4-icon-64x64.png`), bundled in the chart as a data URI unless `consoleLink.imageURL` is set.

**Homepage:** <https://github.com/rh-aiservices-bu/s4>

## Source Code

* <https://github.com/rh-aiservices-bu/s4>
* <https://github.com/eduffy-redhat/s4-role>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://charts/s4 | s4 | 0.1.0 |
| https://charts.validatedpatterns.io | vp-rbac | 0.1.* |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| configJob.activeDeadlineSeconds | int | `3600` |  |
| configJob.configTimeout | int | `1800` |  |
| configJob.disabled | bool | `false` |  |
| configJob.image | string | `"quay.io/validatedpatterns/utility-container:latest"` |  |
| configJob.imagePullPolicy | string | `"IfNotPresent"` |  |
| configJob.s4ReadyTimeoutSeconds | int | `600` |  |
| configJob.schedule | string | `"10 */2 * * *"` |  |
| consoleLink.enabled | bool | `true` |  |
| consoleLink.href | string | `""` |  |
| consoleLink.imageURL | string | `""` |  |
| consoleLink.ingressDomain | string | `""` |  |
| consoleLink.section | string | `"Storage"` |  |
| consoleLink.text | string | `"S4 Web UI"` |  |
| s4.auth.cookieRequireHttps | bool | `true` |  |
| s4.auth.enabled | bool | `true` |  |
| s4.commonAnnotations."argocd.argoproj.io/sync-wave" | string | `"2"` |  |
| s4.image.pullPolicy | string | `"IfNotPresent"` |  |
| s4.image.repository | string | `"quay.io/rh-aiservices-bu/s4"` |  |
| s4.image.tag | string | `"0.3.2"` |  |
| s4.ingress.enabled | bool | `false` |  |
| s4.ingress.s3Api.enabled | bool | `false` |  |
| s4.podSecurityContext.runAsNonRoot | bool | `true` |  |
| s4.route.annotations."haproxy.router.openshift.io/timeout" | string | `"600s"` |  |
| s4.route.enabled | bool | `true` |  |
| s4.route.s3Api.annotations."haproxy.router.openshift.io/timeout" | string | `"600s"` |  |
| s4.route.s3Api.enabled | bool | `true` |  |
| s4.route.s3Api.tls.insecureEdgeTerminationPolicy | string | `"Allow"` |  |
| s4.route.s3Api.tls.termination | string | `"edge"` |  |
| s4.route.tls.insecureEdgeTerminationPolicy | string | `"Redirect"` |  |
| s4.route.tls.termination | string | `"edge"` |  |
| s4.s3.existingSecret | string | `"s4-credentials"` |  |
| s4.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| s4.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| s4.securityContext.runAsNonRoot | bool | `true` |  |
| s4.securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| s4.service.nodePort.enabled | bool | `false` |  |
| s4.service.type | string | `"ClusterIP"` |  |
| s4.serviceAccount.create | bool | `true` |  |
| s4.storage.data.accessMode | string | `"ReadWriteOnce"` |  |
| s4.storage.data.size | string | `"10Gi"` |  |
| s4.storage.data.storageClass | string | `""` |  |
| s4.storage.localStorage.enabled | bool | `false` |  |
| s4APICredentials.vaultKey | string | `"secret/data/global/s4-api-credentials"` |  |
| s4Credentials.secretName | string | `"s4-credentials"` |  |
| s4Role.buckets | list | `[]` |  |
| s4Role.destroy | bool | `false` |  |
| s4Role.endpoint.address | string | `""` |  |
| s4Role.endpoint.port | int | `7480` |  |
| s4Role.endpoint.protocol | string | `"http"` |  |
| s4UICredentials.vaultKey | string | `"secret/data/global/s4-ui-credentials"` |  |
| secretStore.kind | string | `"ClusterSecretStore"` |  |
| secretStore.name | string | `"vault-backend"` |  |
| serviceAccountName | string | `"vp-s4-storage-sa"` |  |
| serviceAccountNamespace | string | `""` |  |
| validationJob.activeDeadlineSeconds | int | `3600` |  |
| validationJob.disabled | bool | `false` |  |
| vp-rbac.roles.external-secrets-validator.namespace | string | `""` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].apiGroups[0] | string | `"external-secrets.io"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].apiGroups[1] | string | `""` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].resources[0] | string | `"externalsecrets"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].resources[1] | string | `"secrets"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].verbs[0] | string | `"get"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].verbs[1] | string | `"list"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].verbs[2] | string | `"watch"` |  |
| vp-rbac.serviceAccounts.vp-s4-storage-sa.namespace | string | `""` |  |
| vp-rbac.serviceAccounts.vp-s4-storage-sa.roleBindings.clusterRoles | list | `[]` |  |
| vp-rbac.serviceAccounts.vp-s4-storage-sa.roleBindings.roles[0] | string | `"external-secrets-validator"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
