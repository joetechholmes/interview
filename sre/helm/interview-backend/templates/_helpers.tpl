{{/*
Expand the name of the chart.
*/}}
{{- define "interview-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "interview-backend.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "interview-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "interview-backend.labels" -}}
helm.sh/chart: {{ include "interview-backend.chart" . }}
{{ include "interview-backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "interview-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "interview-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "interview-backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "interview-backend.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}


{{/*
Sets the Namespaces name
*/}}
{{- define "interview-backend.namespaceName" -}}
{{- if .Values.namespace.nameOverride -}}
{{- .Values.namespace.nameOverride -}}
{{- else -}}
{{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Creates the resource attribute Environment variable
*/}}
{{- define "interview-backend.otelResourceAttributes" -}}
OTEL_RESOURCE_ATTRIBUTES: {{ print "service.version=" .Chart.AppVersion ",deployment.environment=" .Values.env  | quote }}
{{- end -}}
