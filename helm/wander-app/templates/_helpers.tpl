{{/*
Expand the name of the chart.
*/}}
{{- define "wander-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "wander-app.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "wander-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "wander-app.labels" -}}
helm.sh/chart: {{ include "wander-app.chart" . }}
{{ include "wander-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "wander-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wander-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
API labels
*/}}
{{- define "wander-app.api.labels" -}}
{{ include "wander-app.labels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
Frontend labels
*/}}
{{- define "wander-app.frontend.labels" -}}
{{ include "wander-app.labels" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Postgres labels
*/}}
{{- define "wander-app.postgres.labels" -}}
{{ include "wander-app.labels" . }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Redis labels
*/}}
{{- define "wander-app.redis.labels" -}}
{{ include "wander-app.labels" . }}
app.kubernetes.io/component: cache
{{- end }}
