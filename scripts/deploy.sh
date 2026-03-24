#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f k8s/base/namespaces/namespaces.yaml
kubectl apply -f k8s/base/kafka/kafka-cluster.yaml
kubectl apply -f k8s/base/kafka/topics.yaml
kubectl apply -f k8s/base/opensearch/opensearch.yaml
kubectl apply -f k8s/base/exchange-simulator/exchange-simulator.yaml
kubectl apply -f k8s/base/suricata/suricata.yaml
kubectl apply -f k8s/base/network-policies/cilium-policies.yaml

echo 'Deployment manifests applied.'
