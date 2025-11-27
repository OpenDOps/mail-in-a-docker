{{/*
Expand the name of the chart.
*/}}
{{- define "mailinabox.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mailinabox.fullname" -}}
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
{{- define "mailinabox.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mailinabox.labels" -}}
helm.sh/chart: {{ include "mailinabox.chart" . }}
{{ include "mailinabox.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mailinabox.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mailinabox.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Storage class helper
*/}}
{{- define "mailinabox.storageClass" -}}
{{- if .Values.global.storageClass }}
{{- .Values.global.storageClass }}
{{- else if .storageClass }}
{{- .storageClass }}
{{- else }}
{{- "" }}
{{- end }}
{{- end }}

{{/*
Storage class helper that accepts root context
*/}}
{{- define "mailinabox.storageClassFromRoot" -}}
{{- $root := . -}}
{{- if $root.Values.global.storageClass }}
{{- $root.Values.global.storageClass }}
{{- else if .storageClass }}
{{- .storageClass }}
{{- else }}
{{- "" }}
{{- end }}
{{- end }}

{{/*
Generate backendRefs for HTTPRoute rules based on placeholderEnabled setting
Routes to statics-server if placeholderEnabled is true, otherwise routes to mailinabox service
*/}}
{{- define "mailinabox.httproute.backendRefs" -}}
{{- if .Values.gateway.staticsServer.placeholderEnabled }}
# Serve static placeholder page
backendRefs:
- group: ""
  kind: Service
  name: {{ include "mailinabox.fullname" . }}-statics-server
  port: {{ .Values.gateway.staticsServer.port }}
  weight: 1
{{- else }}
# Route to mailinabox service
backendRefs:
- group: ""
  kind: Service
  name: {{ include "mailinabox.fullname" . }}-mailinabox
  port: {{ .Values.mailinabox.service.ports.http }}
  weight: 1
{{- end }}
{{- end }}

{{/*
Convert nodeSelector map to label selector string for Cilium node selection
Example: {kubernetes.io/hostname: node1, node-role.kubernetes.io/gateway: ""} -> "kubernetes.io/hostname=node1,node-role.kubernetes.io/gateway="
*/}}
{{- define "mailinabox.nodeSelectorToLabelString" -}}
{{- $parts := list }}
{{- range $key, $value := . }}
{{- $parts = append $parts (printf "%s=%s" $key ($value | toString)) }}
{{- end }}
{{- $parts | join "," }}
{{- end }}
