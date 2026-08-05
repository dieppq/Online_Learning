{{- define "learnhub-course.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "learnhub-course.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "learnhub-course.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "learnhub-course.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "learnhub-course.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "learnhub-course.labels" -}}
app.kubernetes.io/name: {{ include "learnhub-course.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: learnhub
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "learnhub-course.selectorLabels" -}}
app.kubernetes.io/name: {{ include "learnhub-course.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

