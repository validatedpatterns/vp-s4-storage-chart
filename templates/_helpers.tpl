{{/*
Expand the name of the chart.
*/}}
{{- define "vp-s4-storage.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name for this chart.
*/}}
{{- define "vp-s4-storage.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Match upstream s4.fullname for the s4 subchart values scope.
*/}}
{{- define "vp-s4-storage.s4.fullname" -}}
{{- $s4 := .Values.s4 -}}
{{- if $s4.fullnameOverride }}
{{- $s4.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "s4" $s4.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
In-cluster S3 API hostname for bucket provisioning.
*/}}
{{- define "vp-s4-storage.s4.endpointAddress" -}}
{{- if .Values.s4Role.endpoint.address }}
{{- .Values.s4Role.endpoint.address }}
{{- else }}
{{- include "vp-s4-storage.s4.fullname" . }}
{{- end }}
{{- end }}

{{/*
Shared Job/CronJob pod spec for s4-buckets playbook (imperative-container).
*/}}
{{- define "vp-s4-storage.s4Buckets.configJobSpec" -}}
restartPolicy: Never
serviceAccountName: {{ $.Values.serviceAccountName }}
volumes:
  - name: playbook
    configMap:
      name: {{ include "vp-s4-storage.fullname" $ }}-s4-buckets-playbook
initContainers:
  - name: wait-for-s4
    image: {{ $.Values.configJob.image }}
    imagePullPolicy: {{ $.Values.configJob.imagePullPolicy }}
    env:
      - name: S4_ENDPOINT_HOST
        value: {{ include "vp-s4-storage.s4.endpointAddress" $ | quote }}
      - name: S4_ENDPOINT_PORT
        value: {{ $.Values.s4Role.endpoint.port | quote }}
      - name: S4_READY_TIMEOUT
        value: {{ $.Values.configJob.s4ReadyTimeoutSeconds | quote }}
    command:
      - /bin/bash
      - -c
      - |
          set -euo pipefail
          deadline=$((SECONDS + S4_READY_TIMEOUT))
          echo "Waiting for S4 API on ${S4_ENDPOINT_HOST}:${S4_ENDPOINT_PORT}..."
          until timeout 2 bash -c "echo >/dev/tcp/${S4_ENDPOINT_HOST}/${S4_ENDPOINT_PORT}" 2>/dev/null; do
            if (( SECONDS >= deadline )); then
              echo "ERROR: S4 API port not open within ${S4_READY_TIMEOUT}s"
              exit 1
            fi
            sleep 5
          done
          echo "S4 API port is open"
containers:
  - name: s4-buckets-apply
    image: {{ $.Values.configJob.image }}
    imagePullPolicy: {{ $.Values.configJob.imagePullPolicy }}
    env:
      - name: ANSIBLE_LOCAL_TEMP
        value: /tmp/ansible-local
      - name: S4_BUCKETS
        value: {{ $.Values.s4Role.buckets | toJson | quote }}
      - name: S4_DESTROY
        value: {{ $.Values.s4Role.destroy | quote }}
    command:
      - /bin/bash
      - -c
      - |
          set -euo pipefail
          mkdir -p "${ANSIBLE_LOCAL_TEMP}"
          runtime_vars="$(mktemp)"
          {
            echo "s4_buckets: ${S4_BUCKETS}"
            echo "s4_destroy: ${S4_DESTROY}"
            echo "s4_s4:"
            echo "  endpointUser: \"${AWS_ACCESS_KEY_ID}\""
            echo "  endpointPassword: \"${AWS_SECRET_ACCESS_KEY}\""
          } > "${runtime_vars}"
          exec timeout {{ $.Values.configJob.configTimeout }} ansible-playbook \
            /pattern-home/playbook/s4-buckets.yml \
            -e @/pattern-home/playbook/vars/defaults.yml \
            -e @"${runtime_vars}"
    envFrom:
      - secretRef:
          name: {{ $.Values.s4AdminCredentials.secretName | quote }}
    volumeMounts:
      - name: playbook
        mountPath: /pattern-home/playbook
        readOnly: true
{{- end }}
