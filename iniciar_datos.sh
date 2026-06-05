#!/bin/bash

# --- VARIABLES CON TUS RUTAS EXACTAS ---
JAR_FILE="/home/upm/practica_creativa/flight_prediction/target/scala-2.13/flight_prediction_2.13-0.1.jar"
CSV_FILE="/home/upm/practica_creativa/distances.csv"

echo "⏳ Esperando a que los contenedores estén listos..."
kubectl wait --for=condition=ready pod -l app=cassandra --timeout=120s
kubectl wait --for=condition=ready pod -l app=spark-master --timeout=120s

# Capturamos los nombres dinámicos de los pods
CASSANDRA_POD=$(kubectl get pods -l app=cassandra -o jsonpath='{.items[0].metadata.name}')
SPARK_POD=$(kubectl get pods -l app=spark-master -o jsonpath='{.items[0].metadata.name}')

echo "🚀 1. Configurando Cassandra..."
kubectl exec -i $CASSANDRA_POD -- cqlsh -e "CREATE KEYSPACE IF NOT EXISTS agile_data_science WITH replication = {'class':'SimpleStrategy', 'replication_factor':1}; USE agile_data_science; CREATE TABLE IF NOT EXISTS origin_dest_distances (origin text, dest text, distance float, PRIMARY KEY (origin, dest));"
echo "✅ Base de datos 'agile_data_science' lista."

echo "📦 2. Subiendo el código JAR a Spark..."
if [ -f "$JAR_FILE" ]; then
    kubectl cp $JAR_FILE $SPARK_POD:/opt/spark/flight_prediction.jar
    echo "✅ JAR copiado exitosamente en Spark Master (/opt/spark/flight_prediction.jar)."
else
    echo "❌ ERROR: No se encuentra el archivo JAR en la ruta especificada."
fi

echo "📊 3. Subiendo el archivo de distancias CSV..."
if [ -f "$CSV_FILE" ]; then
    # Lo dejamos en Spark por si tu código lo lee en local
    kubectl cp $CSV_FILE $SPARK_POD:/opt/spark/distances.csv
    echo "✅ CSV copiado a Spark Master (/opt/spark/distances.csv)."
    
    # También lo dejamos en Cassandra por si tienes que hacer un COPY manual después
    kubectl cp $CSV_FILE $CASSANDRA_POD:/tmp/distances.csv
    echo "✅ CSV copiado a Cassandra (/tmp/distances.csv)."
else
    echo "❌ ERROR: No se encuentra el archivo CSV en la ruta especificada."
fi

echo "🎉 ¡Infraestructura de datos lista para la acción!"