#!/usr/bin/env bash
set -euo pipefail

TENANT="${TENANT:-}"
TENANT_ENV="${TENANT_ENV:-dev}"
SIM_IMAGE="${SIM_IMAGE:-ghcr.io/example/exchange-simulator:dev}"

if [[ -z "${TENANT}" ]]; then
  echo "TENANT is required, e.g. TENANT=alpha" >&2
  exit 1
fi

if [[ "${TENANT_ENV}" == "prod" ]] && [[ "${SIM_IMAGE}" != *@sha256:* ]]; then
  echo "In TENANT_ENV=prod, SIM_IMAGE must be digest-pinned (image@sha256:...)" >&2
  exit 1
fi

slug="$(echo "${TENANT}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
if [[ -z "${slug}" ]]; then
  echo "TENANT produced empty slug" >&2
  exit 1
fi

tenant_ns="tenant-${slug}"
telemetry_ns="telemetry"
out_dir="k8s/tenants/${slug}"
out_file="${out_dir}/rendered.yaml"

market_topic="tenant-${slug}.market-events"
audit_topic="tenant-${slug}.simulator-audit"
suricata_topic="tenant-${slug}.suricata-eve"
index_group="tenant-${slug}-indexer"

sim_user="tenant-${slug}-simulator-user"
eve_user="tenant-${slug}-eve-forwarder-user"
index_user="tenant-${slug}-indexer-user"

sim_name="exchange-simulator-${slug}"
sim_cfg="${sim_name}-config"

template_name="tenant-${slug}-events-template"
alias_name="tenant-${slug}-events"
ilm_name="tenant-${slug}-hot-delete-7d"

mkdir -p "${out_dir}"

cat > "${out_file}" <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${tenant_ns}
  labels:
    tenant: ${slug}
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${sim_cfg}
  namespace: ${tenant_ns}
  labels:
    tenant: ${slug}
data:
  APP_NAME: ${sim_name}
  KAFKA_BOOTSTRAP_SERVERS: exchange-kafka-kafka-bootstrap.${telemetry_ns}.svc.cluster.local:9093
  MARKET_EVENTS_TOPIC: ${market_topic}
  AUDIT_TOPIC: ${audit_topic}
  FIX_LISTEN_HOST: 0.0.0.0
  FIX_LISTEN_PORT: '9878'
  HTTP_PORT: '8080'
  SYMBOLS: BTC-USD,ETH-USD,SOL-USD,AAPL,TSLA,NVDA
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${sim_name}
  namespace: ${tenant_ns}
  labels:
    app: ${sim_name}
    tenant: ${slug}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${sim_name}
      tenant: ${slug}
  template:
    metadata:
      labels:
        app: ${sim_name}
        tenant: ${slug}
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: exchange-simulator
          image: ${SIM_IMAGE}
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          envFrom:
            - configMapRef:
                name: ${sim_cfg}
          env:
            - name: KAFKA_SECURITY_PROTOCOL
              value: SASL_SSL
            - name: KAFKA_SASL_MECHANISM
              value: SCRAM-SHA-512
            - name: KAFKA_SASL_USERNAME
              value: ${sim_user}
            - name: KAFKA_SASL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${sim_user}
                  key: password
            - name: KAFKA_SSL_CA_LOCATION
              value: /etc/kafka/ca.crt
          ports:
            - name: http
              containerPort: 8080
            - name: fix
              containerPort: 9878
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: kafka-cluster-ca
              mountPath: /etc/kafka
              readOnly: true
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: kafka-cluster-ca
          secret:
            secretName: exchange-kafka-cluster-ca-cert
            optional: true
        - name: tmp
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: ${sim_name}
  namespace: ${tenant_ns}
  labels:
    tenant: ${slug}
spec:
  selector:
    app: ${sim_name}
    tenant: ${slug}
  ports:
    - name: http
      port: 8080
      targetPort: 8080
    - name: fix
      port: 9878
      targetPort: 9878
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${sim_name}-default-deny
  namespace: ${tenant_ns}
  labels:
    tenant: ${slug}
spec:
  podSelector:
    matchLabels:
      app: ${sim_name}
  policyTypes: ["Ingress", "Egress"]
  ingress:
    - ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 9878
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ${telemetry_ns}
      ports:
        - protocol: TCP
          port: 9093
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: ${market_topic}
  namespace: ${telemetry_ns}
  labels:
    strimzi.io/cluster: exchange-kafka
    tenant: ${slug}
spec:
  partitions: 6
  replicas: 3
  config:
    retention.ms: 604800000
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: ${audit_topic}
  namespace: ${telemetry_ns}
  labels:
    strimzi.io/cluster: exchange-kafka
    tenant: ${slug}
spec:
  partitions: 6
  replicas: 3
  config:
    retention.ms: 604800000
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: ${suricata_topic}
  namespace: ${telemetry_ns}
  labels:
    strimzi.io/cluster: exchange-kafka
    tenant: ${slug}
spec:
  partitions: 6
  replicas: 3
  config:
    retention.ms: 604800000
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: ${sim_user}
  namespace: ${telemetry_ns}
  labels:
    strimzi.io/cluster: exchange-kafka
    tenant: ${slug}
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: ${market_topic}
          patternType: literal
        operations: ["Write", "Describe"]
      - resource:
          type: topic
          name: ${audit_topic}
          patternType: literal
        operations: ["Write", "Describe"]
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: ${eve_user}
  namespace: ${telemetry_ns}
  labels:
    strimzi.io/cluster: exchange-kafka
    tenant: ${slug}
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: ${suricata_topic}
          patternType: literal
        operations: ["Write", "Describe"]
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: ${index_user}
  namespace: ${telemetry_ns}
  labels:
    strimzi.io/cluster: exchange-kafka
    tenant: ${slug}
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: ${market_topic}
          patternType: literal
        operations: ["Read", "Describe"]
      - resource:
          type: topic
          name: ${audit_topic}
          patternType: literal
        operations: ["Read", "Describe"]
      - resource:
          type: topic
          name: ${suricata_topic}
          patternType: literal
        operations: ["Read", "Describe"]
      - resource:
          type: group
          name: ${index_group}
          patternType: literal
        operations: ["Read", "Describe"]
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tenant-${slug}-opensearch-governance
  namespace: ${telemetry_ns}
  labels:
    tenant: ${slug}
data:
  INDEX_TEMPLATE_NAME: ${template_name}
  INDEX_ALIAS: ${alias_name}
  ILM_POLICY_NAME: ${ilm_name}
  INDEX_PATTERNS: "${market_topic}-*,${audit_topic}-*,${suricata_topic}-*"
YAML

echo "Generated ${out_file}"
