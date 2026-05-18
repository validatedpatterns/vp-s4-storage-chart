# s4

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.3.2](https://img.shields.io/badge/AppVersion-0.3.2-informational?style=flat-square)

S4 (Super Simple Storage Service) - A lightweight S3-compatible storage solution

**Homepage:** <https://github.com/rh-aiservices-bu/s4>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Red Hat AI Services BU |  |  |

## Source Code

* <https://github.com/rh-aiservices-bu/s4>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity rules |
| auth.cookieRequireHttps | bool | `true` | Require HTTPS for cookies (disable for local development) |
| auth.enabled | bool | `true` | Enable UI authentication |
| auth.jwtExpirationHours | int | `8` | JWT token expiration in hours |
| auth.jwtSecret | string | `""` | JWT secret key (auto-generated if empty) |
| auth.password | string | `""` | Password for UI login (stored in secret) |
| auth.username | string | `""` | Username for UI login (stored in secret) |
| commonAnnotations | object | `{}` | Additional annotations to add to all resources |
| commonLabels | object | `{}` | Additional labels to add to all resources |
| extraEnv | list | `[]` | Additional environment variables |
| extraVolumeMounts | list | `[]` | Additional volume mounts |
| extraVolumes | list | `[]` | Additional volumes |
| fullnameOverride | string | `""` | Override the full name |
| image.pullPolicy | string | `"Always"` | Image pull policy |
| image.repository | string | `"quay.io/rh-aiservices-bu/s4"` | Container image repository |
| image.tag | string | `"latest"` | Container image tag |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.className | string | `""` | Ingress class name |
| ingress.enabled | bool | `false` | Enable ingress |
| ingress.hosts | list | `[]` | Ingress hosts configuration |
| ingress.s3Api.annotations | object | `{}` |  |
| ingress.s3Api.className | string | `""` |  |
| ingress.s3Api.enabled | bool | `false` |  |
| ingress.s3Api.hosts | list | `[]` |  |
| ingress.s3Api.tls | list | `[]` |  |
| ingress.tls | list | `[]` | Ingress TLS configuration |
| nameOverride | string | `""` | Override the chart name |
| nodeSelector | object | `{}` | Node selector |
| podSecurityContext.runAsNonRoot | bool | `true` | Run as non-root user |
| probes.liveness.failureThreshold | int | `3` | Failure threshold |
| probes.liveness.initialDelaySeconds | int | `60` | Initial delay before probe starts |
| probes.liveness.periodSeconds | int | `30` | Probe interval |
| probes.liveness.timeoutSeconds | int | `10` | Probe timeout |
| probes.readiness.failureThreshold | int | `3` | Failure threshold |
| probes.readiness.initialDelaySeconds | int | `15` | Initial delay before probe starts |
| probes.readiness.periodSeconds | int | `10` | Probe interval |
| probes.readiness.timeoutSeconds | int | `5` | Probe timeout |
| replicaCount | int | `1` | Number of replicas (only 1 supported due to SQLite backend) |
| resources.limits.cpu | string | `"2000m"` | CPU limit |
| resources.limits.memory | string | `"2Gi"` | Memory limit |
| resources.requests.cpu | string | `"250m"` | CPU request |
| resources.requests.memory | string | `"512Mi"` | Memory request |
| route.annotations | object | `{}` | Route annotations |
| route.enabled | bool | `true` | Enable OpenShift Route |
| route.host | string | `""` | Route hostname (auto-generated if empty) |
| route.path | string | `""` | Route path |
| route.s3Api.annotations | object | `{}` |  |
| route.s3Api.enabled | bool | `false` |  |
| route.s3Api.host | string | `""` |  |
| route.s3Api.path | string | `""` |  |
| route.s3Api.tls.insecureEdgeTerminationPolicy | string | `"Redirect"` |  |
| route.s3Api.tls.termination | string | `"edge"` |  |
| route.tls.insecureEdgeTerminationPolicy | string | `"Redirect"` | Insecure edge termination policy (Allow, Redirect, None) |
| route.tls.termination | string | `"edge"` | TLS termination type (edge, passthrough, reencrypt) |
| s3.accessKeyId | string | `"s4admin"` | S3 access key ID (stored in secret) |
| s3.endpoint | string | `"http://localhost:7480"` | S3 endpoint URL (use localhost:7480 for internal RGW) |
| s3.existingSecret | string | `""` | Use existing secret for S3 credentials If set, s3.accessKeyId and s3.secretAccessKey are ignored Secret must contain AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY keys |
| s3.region | string | `"us-east-1"` | S3 region |
| s3.secretAccessKey | string | `"s4secret"` | S3 secret access key (stored in secret) |
| securityContext.allowPrivilegeEscalation | bool | `false` | Disallow privilege escalation |
| securityContext.capabilities | object | `{"drop":["ALL"]}` | Drop all capabilities |
| securityContext.runAsNonRoot | bool | `true` | Run as non-root user |
| securityContext.seccompProfile | object | `{"type":"RuntimeDefault"}` | Seccomp profile |
| server.ip | string | `"0.0.0.0"` | Server bind address |
| server.port | int | `5000` | Server port |
| service.nodePort.enabled | bool | `false` | Enable NodePort service |
| service.nodePort.s3Port | string | `""` | NodePort for S3 API (optional, auto-assigned if empty) |
| service.nodePort.webPort | string | `""` | NodePort for web UI (optional, auto-assigned if empty) |
| service.port | int | `5000` | Web UI port |
| service.s3Port | int | `7480` | S3 API port |
| service.type | string | `"ClusterIP"` | Service type (ClusterIP, NodePort, LoadBalancer) |
| serviceAccount.annotations | object | `{}` | Service account annotations |
| serviceAccount.create | bool | `true` | Create service account |
| serviceAccount.name | string | `""` | Service account name (auto-generated if empty) |
| storage.data.accessMode | string | `"ReadWriteOnce"` | Access mode |
| storage.data.existingClaim | string | `""` | Use existing PVC instead of creating one |
| storage.data.size | string | `"10Gi"` | Storage size for RGW data |
| storage.data.storageClass | string | `""` | Storage class (empty for default) |
| storage.localPaths | string | `""` | Local storage paths (comma-separated, empty to disable local file browser) |
| storage.localStorage.accessMode | string | `"ReadWriteOnce"` | Access mode |
| storage.localStorage.enabled | bool | `false` | Enable local storage volume (set to true if using local file browser) |
| storage.localStorage.existingClaim | string | `""` | Use existing PVC instead of creating one |
| storage.localStorage.size | string | `"50Gi"` | Storage size for local storage |
| storage.localStorage.storageClass | string | `""` | Storage class (empty for default) |
| storage.maxConcurrentTransfers | int | `2` | Maximum concurrent transfers |
| storage.maxFileSizeGB | int | `20` | Maximum file size in GB |
| tolerations | list | `[]` | Tolerations |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
