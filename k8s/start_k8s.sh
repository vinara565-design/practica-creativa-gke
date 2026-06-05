#!/bin/bash
echo "🚀 Arrancando K8S..."

minikube start

echo "⏳ Esperando a que los pods estén listos..."
kubectl wait --for=condition=ready pod -l app=kafka --timeout=120s 2>/dev/null
kubectl wait --for=condition=ready pod -l app=mongo --timeout=120s 2>/dev/null
kubectl wait --for=condition=ready pod -l app=cassandra --timeout=120s 2>/dev/null
kubectl wait --for=condition=ready pod -l app=minio --timeout=120s 2>/dev/null
kubectl wait --for=condition=ready pod -l app=spark-master --timeout=120s 2>/dev/null
kubectl wait --for=condition=ready pod -l app=spark-worker --timeout=120s 2>/dev/null
kubectl wait --for=condition=ready pod -l app=flask --timeout=120s 2>/dev/null

echo "🔄 Lanzando Spark Streaming..."
kubectl delete job spark-submit-job 2>/dev/null || true
kubectl apply -f ~/practica_creativa/k8s/spark-submit.yaml

echo ""
echo "=== ESTADO PODS ==="
kubectl get pods

echo ""
echo "========================================"
echo "           RESUMEN DE ACCESOS K8S"
echo "========================================"
MINIKUBE_IP=$(minikube ip)
echo "🌐 Web predicción:  http://$MINIKUBE_IP:30001/flights/delays/predict_kafka"
echo "========================================"
echo ""
echo "✅ K8S listo!"
