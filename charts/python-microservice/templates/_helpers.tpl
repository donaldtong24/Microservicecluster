{{/*
Chart name used for resource naming and labels.
*/}}
{{- define "python-microservice.name" -}}
python-microservice
{{- end -}}

{{/*
Common labels applied to every resource this chart manages.
*/}}
{{- define "python-microservice.labels" -}}
app: python-app
app.kubernetes.io/name: {{ include "python-microservice.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
