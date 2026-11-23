{{- define "transmission.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "transmission.labels" -}}
{{ include "transmission.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/* Without the chart's version, so a release that changes only the chart doesn't restart Transmission. */}}
{{- define "transmission.podLabels" -}}
{{ include "transmission.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{- define "transmission.secretKeyRef" -}}
{{- $path := index . 0 }}
{{- $ref := (index . 1).secretKeyRef }}
secretKeyRef:
  name: {{ required (printf "%s.secretKeyRef.name is required" $path) $ref.name }}
  key: {{ required (printf "%s.secretKeyRef.key is required" $path) $ref.key }}
{{- end }}

{{- define "transmission.image" -}}
lscr.io/linuxserver/transmission:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{/* Transmission's own containers run in LinuxServer's non-root mode. */}}
{{- define "transmission.securityContext" -}}
runAsUser: {{ .Values.puid }}
runAsGroup: {{ .Values.pgid }}
runAsNonRoot: true
allowPrivilegeEscalation: false
capabilities:
  drop: [ALL]
{{- end }}

{{- define "transmission.validate" -}}
{{- $v := .Values }}
{{- required "persistence.config.existingClaim is required" $v.persistence.config.existingClaim }}
{{- required "persistence.incomplete.existingClaim is required" $v.persistence.incomplete.existingClaim }}
{{- required "gluetun.firewallOutboundSubnets is required" $v.gluetun.firewallOutboundSubnets }}
{{- if not $v.gluetun.env }}
{{- fail "gluetun.env is required: it holds the VPN provider's settings" }}
{{- end }}
{{- if not $v.persistence.media }}
{{- fail "persistence.media needs at least one mount" }}
{{- end }}
{{- $under := false }}
{{- range $v.persistence.media }}
{{- $name := required "each persistence.media mount needs a name" .name }}
{{- required (printf "persistence.media mount %s needs an existingClaim" $name) .existingClaim }}
{{- $path := required (printf "persistence.media mount %s needs a mountPath" $name) .mountPath }}
{{- if or (eq $path $v.downloadDir) (hasPrefix (printf "%s/" (trimSuffix "/" $path)) $v.downloadDir) }}
{{- $under = true }}
{{- end }}
{{- end }}
{{- required "downloadDir is required" $v.downloadDir }}
{{- if not $under }}
{{- fail "downloadDir must be inside a persistence.media mountPath" }}
{{- end }}
{{- end }}
