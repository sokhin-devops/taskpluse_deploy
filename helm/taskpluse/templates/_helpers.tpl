{{/* Every object is named after the release: helm install <release> ... */}}
{{- define "taskpluse.fullname" -}}
{{- .Release.Name | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels that never change for a component - the Deployment's selector.
     Call with (dict "root" $ "component" "api"). */}}
{{- define "taskpluse.selectorLabels" -}}
app.kubernetes.io/name: taskpluse
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Full labels: selector labels plus version and ownership.
     Call with (dict "root" $ "component" "api" "version" <image tag>). */}}
{{- define "taskpluse.labels" -}}
{{ include "taskpluse.selectorLabels" . }}
app.kubernetes.io/version: {{ .version | default "none" | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version }}
{{- end -}}
