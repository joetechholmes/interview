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

{{/*
Downward API env vars that inject pod metadata into OTel resource attributes.
The explicit OTEL_RESOURCE_ATTRIBUTES entry here overrides the ConfigMap value at runtime,
adding k8s.pod.name which cannot be set statically in a ConfigMap.
*/}}
{{- define "interview-backend.otelK8sEnv" -}}
- name: K8S_POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "k8s.pod.name=$(K8S_POD_NAME),service.version=%s,deployment.environment=%s" .Chart.AppVersion .Values.env | quote }}
{{- end -}}
