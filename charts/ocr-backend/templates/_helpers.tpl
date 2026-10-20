{{- define "ocr-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ocr-backend.fullname" -}}
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

{{- define "ocr-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ocr-backend.labels" -}}
helm.sh/chart: {{ include "ocr-backend.chart" . }}
{{ include "ocr-backend.selectorLabels" . }}
app.kubernetes.io/version: {{ include "ocr-backend.tag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: nilam-ocr
{{- end }}

{{- define "ocr-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ocr-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "ocr-backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ocr-backend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "ocr-backend.tag" -}}
{{- default .Chart.AppVersion .Values.image.tag }}
{{- end }}

{{/* api and worker MUST run the same image, so both use this. */}}
{{- define "ocr-backend.image" -}}
{{- $repo := printf "%s/%s" .Values.image.registry .Values.image.repository }}
{{- if .Values.image.digest }}
{{- printf "%s@%s" $repo .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" $repo (include "ocr-backend.tag" .) }}
{{- end }}
{{- end }}

{{/* APM env for one component; the service name is per Deployment so api and worker stay separate in APM. */}}
{{- define "ocr-backend.apmEnv" -}}
{{- $ := index . 0 }}
{{- $component := index . 1 }}
{{- with $.Values.apm }}
{{- if .serverUrl }}
- name: ELASTIC_APM_SERVER_URL
  value: {{ .serverUrl | quote }}
- name: ELASTIC_APM_SERVICE_NAME
  value: {{ printf "%s-%s" (include "ocr-backend.fullname" $) $component | quote }}
- name: ELASTIC_APM_ENVIRONMENT
  value: {{ .environment | quote }}
- name: ELASTIC_APM_TRANSACTION_SAMPLE_RATE
  value: {{ .sampleRate | quote }}
- name: ELASTIC_APM_SANITIZE_FIELD_NAMES
  value: {{ .sanitizeFieldNames | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/* Pod spec parts shared by api and worker. Argument: (list $ "api"|"worker"). */}}
{{- define "ocr-backend.podCommon" -}}
{{- $ := index . 0 }}
{{- $component := index . 1 }}
serviceAccountName: {{ include "ocr-backend.serviceAccountName" $ }}
automountServiceAccountToken: {{ $.Values.automountServiceAccountToken }}
{{- with $.Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
securityContext:
  {{- toYaml $.Values.podSecurityContext | nindent 2 }}
{{- with $.Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $.Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $.Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if $.Values.topologySpread.enabled }}
topologySpreadConstraints:
  - maxSkew: {{ $.Values.topologySpread.maxSkew }}
    topologyKey: {{ $.Values.topologySpread.topologyKey }}
    whenUnsatisfiable: {{ $.Values.topologySpread.whenUnsatisfiable }}
    labelSelector:
      matchLabels:
        {{- include "ocr-backend.selectorLabels" $ | nindent 8 }}
        app.kubernetes.io/component: {{ $component }}
{{- end }}
{{- end }}
