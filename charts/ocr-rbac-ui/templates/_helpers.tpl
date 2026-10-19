{{- define "ocr-rbac-ui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ocr-rbac-ui.fullname" -}}
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

{{- define "ocr-rbac-ui.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ocr-rbac-ui.labels" -}}
helm.sh/chart: {{ include "ocr-rbac-ui.chart" . }}
{{ include "ocr-rbac-ui.selectorLabels" . }}
app.kubernetes.io/version: {{ include "ocr-rbac-ui.tag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: nilam-ocr
app.kubernetes.io/component: frontend
{{- end }}

{{- define "ocr-rbac-ui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ocr-rbac-ui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "ocr-rbac-ui.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ocr-rbac-ui.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "ocr-rbac-ui.tag" -}}
{{- default .Chart.AppVersion .Values.image.tag }}
{{- end }}

{{- define "ocr-rbac-ui.image" -}}
{{- $repo := printf "%s/%s" .Values.image.registry .Values.image.repository }}
{{- if .Values.image.digest }}
{{- printf "%s@%s" $repo .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" $repo (include "ocr-rbac-ui.tag" .) }}
{{- end }}
{{- end }}

{{- define "ocr-rbac-ui.apiUpstream" -}}
{{- $ns := default .Release.Namespace .Values.backend.namespace }}
{{- printf "http://%s.%s.svc.cluster.local:%v" .Values.backend.serviceName $ns .Values.backend.port }}
{{- end }}
