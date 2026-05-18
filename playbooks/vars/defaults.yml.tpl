---
# Default variables for s4-buckets.yml (overridden at runtime by the Job/CronJob)
s4_s4:
  endpointProtocol: {{ .Values.s4Role.endpoint.protocol | quote }}
  endpointAddress: {{ include "vp-s4-storage.s4.endpointAddress" . | quote }}
  endpointPort: {{ .Values.s4Role.endpoint.port }}
  endpointUser: ""
  endpointPassword: ""
s4_destroy: {{ .Values.s4Role.destroy }}
s4_buckets: []
