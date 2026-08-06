{{- define "learnhub-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "learnhub-common.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "learnhub-common.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "learnhub-common.labels" -}}
app.kubernetes.io/name: {{ include "learnhub-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: learnhub
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "learnhub-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "learnhub-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "learnhub-common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "learnhub-common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "learnhub-common.configMapName" -}}
{{- if .Values.configMap.create -}}
{{- include "learnhub-common.fullname" . -}}
{{- else -}}
{{- required "configMap.existingName is required when configMap is enabled and create is false" .Values.configMap.existingName -}}
{{- end -}}
{{- end -}}

{{- define "learnhub-common.resources" -}}
{{- if .Values.database.deploy }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Values.database.host }}-data
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
    app.kubernetes.io/component: database
    learnhub.io/owner: {{ .Values.database.owner }}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.database.storage.size }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.database.host }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
    app.kubernetes.io/component: database
    app.kubernetes.io/version: {{ .Values.database.image.tag | quote }}
    learnhub.io/owner: {{ .Values.database.owner }}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Values.database.host }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Values.database.host }}
        app.kubernetes.io/instance: {{ .Release.Name }}
        app.kubernetes.io/part-of: learnhub
        app.kubernetes.io/component: database
        app.kubernetes.io/version: {{ .Values.database.image.tag | quote }}
        learnhub.io/owner: {{ .Values.database.owner }}
    spec:
      serviceAccountName: {{ include "learnhub-common.serviceAccountName" . }}
      automountServiceAccountToken: false
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: postgresql
          image: "{{ .Values.database.image.repository }}:{{ .Values.database.image.tag }}"
          imagePullPolicy: {{ .Values.database.image.pullPolicy }}
          ports:
            - name: postgres
              containerPort: {{ .Values.database.port }}
          envFrom:
            - secretRef:
                name: {{ required "database.secretName is required when database is enabled" .Values.database.secretName }}
          env:
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
          resources:
            {{- toYaml .Values.database.resources | nindent 12 }}
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            exec:
              command:
                - sh
                - -c
                - pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
            initialDelaySeconds: 20
            periodSeconds: 20
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: {{ .Values.database.host }}-data
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.database.host }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
    app.kubernetes.io/component: database
    learnhub.io/owner: {{ .Values.database.owner }}
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: {{ .Values.database.host }}
    app.kubernetes.io/instance: {{ .Release.Name }}
  ports:
    - name: postgres
      port: {{ .Values.database.port }}
      targetPort: postgres
---
{{- end }}
{{- if and .Values.database.enabled .Values.database.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "learnhub-common.fullname" . }}-database
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      learnhub.io/owner: {{ .Values.database.owner }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              learnhub.io/owner: {{ .Values.database.owner }}
      ports:
        - protocol: TCP
          port: {{ .Values.database.port }}
  egress:
    - to:
        - podSelector:
            matchLabels:
              learnhub.io/owner: {{ .Values.database.owner }}
      ports:
        - protocol: TCP
          port: {{ .Values.database.port }}
---
{{- end }}
{{- if and .Values.database.enabled (dig "migration" "enabled" false .Values.database) }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "learnhub-common.fullname" . }}-db-migrate-v{{ .Values.database.migration.version }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
    app.kubernetes.io/component: migration
    learnhub.io/owner: {{ .Values.database.owner }}
spec:
  backoffLimit: 3
  template:
    metadata:
      labels:
        {{- include "learnhub-common.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/part-of: learnhub
        app.kubernetes.io/component: migration
        learnhub.io/owner: {{ .Values.database.owner }}
    spec:
      automountServiceAccountToken: false
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 70
        runAsGroup: 70
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: migrate
          image: "{{ .Values.database.image.repository }}:{{ .Values.database.image.tag }}"
          imagePullPolicy: {{ .Values.database.image.pullPolicy }}
          command: ["sh", "-c"]
          args:
            - |
              set -eu
              until PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1" >/dev/null 2>&1; do sleep 2; done
              PGPASSWORD="$POSTGRES_PASSWORD" psql -v ON_ERROR_STOP=1 -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<'SQL'
              CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());
              {{- with .Values.database.migration.file }}
              {{- $.Files.Get . | nindent 14 }}
              {{- end }}
              INSERT INTO schema_migrations(version) VALUES ('{{ .Values.database.migration.version }}') ON CONFLICT DO NOTHING;
              SQL
              echo migration={{ include "learnhub-common.name" . }}:{{ .Values.database.migration.version }} status=applied
          envFrom:
            - secretRef:
                name: {{ required "database.secretName is required when database is enabled" .Values.database.secretName }}
          env:
            - name: POSTGRES_HOST
              value: {{ .Values.database.host }}
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
---
{{- end }}
{{- if and .Values.configMap.enabled .Values.configMap.create }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "learnhub-common.configMapName" . }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
data:
  {{- toYaml .Values.configMap.data | nindent 2 }}
---
{{- end }}
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "learnhub-common.serviceAccountName" . }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
---
{{- end }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "learnhub-common.fullname" . }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ .Values.component }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  minReadySeconds: 5
  progressDeadlineSeconds: 300
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      {{- include "learnhub-common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "learnhub-common.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/part-of: learnhub
        app.kubernetes.io/component: {{ .Values.component }}
        app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ include "learnhub-common.serviceAccountName" . }}
      automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
      terminationGracePeriodSeconds: 30
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- if and .Values.database.enabled .Values.database.waitForReady }}
      initContainers:
        - name: wait-for-database
          image: "{{ .Values.database.image.repository }}:{{ .Values.database.image.tag }}"
          imagePullPolicy: {{ .Values.database.image.pullPolicy }}
          command:
            - sh
            - -c
            - |
              until PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1"; do
                echo "waiting for $POSTGRES_HOST"
                sleep 2
              done
          envFrom:
            - secretRef:
                name: {{ required "database.secretName is required when database is enabled" .Values.database.secretName }}
          env:
            - name: POSTGRES_HOST
              value: {{ .Values.database.host }}
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 70
            runAsGroup: 70
            capabilities:
              drop:
                - ALL
      {{- end }}
      containers:
        - name: {{ .Values.container.name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: {{ .Values.container.portName }}
              containerPort: {{ .Values.container.port }}
          {{- if or .Values.configMap.enabled .Values.secret.enabled .Values.database.enabled }}
          envFrom:
            {{- if .Values.configMap.enabled }}
            - configMapRef:
                name: {{ include "learnhub-common.configMapName" . }}
                optional: {{ .Values.configMap.optional }}
            {{- end }}
            {{- if .Values.secret.enabled }}
            - secretRef:
                name: {{ required "secret.existingName is required when secret is enabled" .Values.secret.existingName }}
                optional: {{ .Values.secret.optional }}
            {{- end }}
            {{- if .Values.database.enabled }}
            - secretRef:
                name: {{ required "database.secretName is required when database is enabled" .Values.database.secretName }}
            {{- end }}
          {{- end }}
          env:
            - name: APP_VERSION
              value: {{ .Chart.AppVersion | quote }}
            - name: RELEASE_ID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['app.kubernetes.io/version']
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            {{- if .Values.database.enabled }}
            - name: POSTGRES_HOST
              value: {{ .Values.database.host }}
            - name: POSTGRES_PORT
              value: {{ .Values.database.port | quote }}
            {{- end }}
            {{- with .Values.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.probes.readiness | nindent 12 }}
          livenessProbe:
            {{- toYaml .Values.probes.liveness | nindent 12 }}
          {{- if .Values.probes.startup.enabled }}
          startupProbe:
            {{- omit .Values.probes.startup "enabled" | toYaml | nindent 12 }}
          {{- end }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          {{- with .Values.extraVolumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.extraVolumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "learnhub-common.fullname" . }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ .Values.component }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "learnhub-common.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.container.portName }}
---
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "learnhub-common.fullname" . }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
    app.kubernetes.io/component: autoscaling
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "learnhub-common.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
---
{{- end }}
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "learnhub-common.fullname" . }}
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
spec:
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  selector:
    matchLabels:
      {{- include "learnhub-common.selectorLabels" . | nindent 6 }}
---
{{- end }}
{{- if .Values.test.enabled }}
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "learnhub-common.fullname" . }}-test-connection
  labels:
    {{- include "learnhub-common.labels" . | nindent 4 }}
  annotations:
    helm.sh/hook: test
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
    - name: curl
      image: {{ .Values.test.image }}
      command:
        - sh
        - -c
      args:
        - curl --fail --silent --show-error http://{{ include "learnhub-common.fullname" . }}:{{ .Values.service.port }}{{ .Values.test.path }}
      resources:
        requests:
          cpu: 5m
          memory: 16Mi
        limits:
          cpu: 50m
          memory: 32Mi
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
{{- end }}
{{- end -}}
