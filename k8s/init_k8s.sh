#!/bin/bash
set -e

echo "🔧 Inicializando datos en K8S..."

echo "⏳ Esperando a que Cassandra y MinIO estén listos..."
kubectl rollout status deployment/cassandra --timeout=150s
kubectl rollout status deployment/minio --timeout=150s

CASS_POD=$(kubectl get pods -l app=cassandra -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')

# 1. Inicializar Cassandra
echo "💾 Configurando Cassandra..."
cat > /tmp/init_k8s.cql << 'CQLEOF'
CREATE KEYSPACE IF NOT EXISTS agile_data_science WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
CREATE TABLE IF NOT EXISTS agile_data_science.origin_dest_distances (
    origin TEXT,
    dest TEXT,
    distance float,
    PRIMARY KEY (origin, dest)
);
CREATE TABLE IF NOT EXISTS agile_data_science.flight_delay_ml_response (
    uuid text PRIMARY KEY,
    origin text,
    dest text,
    carrier text,
    prediction double,
    timestamp text,
    depdelay double,
    dayofweek int,
    dayofyear int,
    dayofmonth int,
    flightdate text,
    distance double,
    route text
);
CQLEOF

kubectl cp /tmp/init_k8s.cql $CASS_POD:/tmp/init_k8s.cql
kubectl exec $CASS_POD -- cqlsh -f /tmp/init_k8s.cql

# 2. Exportar distancias de Cassandra Docker
echo "📊 Exportando distancias de Cassandra Docker..."
docker start cassandra 2>/dev/null || true
sleep 30
docker exec -i cassandra cqlsh -e "COPY agile_data_science.origin_dest_distances TO '/tmp/distances.csv' WITH HEADER = FALSE AND DELIMITER = ',';"
docker cp cassandra:/tmp/distances.csv /tmp/distances.csv
docker stop cassandra 2>/dev/null || true

# 3. Importar distancias a K8S
echo "📊 Importando 4696 distancias a Cassandra K8S..."
kubectl cp /tmp/distances.csv $CASS_POD:/tmp/distances.csv
kubectl exec -i $CASS_POD -- cqlsh -e "COPY agile_data_science.origin_dest_distances (origin, dest, distance) FROM '/tmp/distances.csv' WITH HEADER = FALSE AND DELIMITER = ',';"
echo "✅ Cassandra OK"

# 4. Inicializar MinIO
echo "📦 Configurando MinIO..."
kubectl port-forward svc/minio 9000:9000 > /dev/null 2>&1 &
PID_FORWARD=$!
sleep 3

mc alias set k8sminio http://localhost:9000 minioadmin minioadmin
mc mb k8sminio/lakehouse 2>/dev/null || true
mc cp ~/practica_creativa/flight_prediction/target/scala-2.13/flight_prediction_2.13-0.1.jar k8sminio/lakehouse/jars/flight_prediction_2.13-0.1.jar
mc cp --recursive ~/practica_creativa/models/ k8sminio/lakehouse/models/
kill $PID_FORWARD
echo " MinIO OK"

echo "🚀 ¡K8S listo!"