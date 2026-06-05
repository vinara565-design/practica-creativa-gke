#!/bin/bash
echo "🚀 Arrancando practica_creativa..."

# 1. Parar MongoDB del sistema si está corriendo
sudo systemctl stop mongod 2>/dev/null

# 2. Levantar todos los contenedores
cd ~/practica_creativa
RUNNING=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
if [ "$RUNNING" -gt "5" ]; then
  echo "✅ Sistema ya arrancado ($RUNNING servicios corriendo) - solo verificando..."
  docker compose up -d --no-recreate 
else
  echo "🔄 Arrancando servicios..."
  docker compose up -d 
fi

if [ "$RUNNING" -gt "5" ]; then
  sleep 5
else
  echo "⏳ Esperando a que los servicios arranquen..."
  sleep 30
fi

# 3. Verificar contenedores
echo ""
echo "=== ESTADO CONTENEDORES ==="
docker compose ps

# 4. Kafka topics
echo ""
echo "=== KAFKA TOPICS ==="
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic flight-delay-ml-request --partitions 1 --replication-factor 1 2>/dev/null || echo "✅ flight-delay-ml-request ya existe"
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic flight-delay-ml-response --partitions 1 --replication-factor 1 2>/dev/null || echo "✅ flight-delay-ml-response ya existe"
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# 5. MongoDB
echo ""
echo "=== MONGODB ==="
docker exec mongo mongo agile_data_science --eval "db.origin_dest_distances.count()" 2>/dev/null | grep -E "^[0-9]+" && echo "✅ MongoDB OK" || echo "❌ MongoDB ERROR"

# 6. Cassandra
echo ""
echo "=== CASSANDRA ==="
docker exec -i cassandra cqlsh -e "SELECT COUNT(*) FROM agile_data_science.origin_dest_distances;" 2>/dev/null | grep -E "[0-9]+" && echo "✅ Cassandra OK" || echo "❌ Cassandra ERROR"

# 7. MinIO
echo ""
echo "=== MINIO ==="
docker exec minio mc alias set local http://localhost:9000 minioadmin minioadmin 2>/dev/null
docker exec minio mc ls local/lakehouse/models/ 2>/dev/null | grep -c "bin" | xargs -I{} echo "✅ MinIO OK - {} modelos encontrados" || echo "❌ MinIO ERROR"

# 8. Spark
echo ""
echo "=== SPARK ==="
curl -s http://localhost:8080 | grep -o "Workers: [0-9]*" | head -1 && echo "✅ Spark Master OK" || echo "❌ Spark Master ERROR"

DRIVERS=$(docker exec spark-worker-1 find /opt/spark/work -name "stderr" 2>/dev/null | wc -l)
if [ "$DRIVERS" -gt "0" ]; then
  echo "✅ Spark en modo CLUSTER - driver corriendo en worker ($DRIVERS drivers encontrados)"
else
  DRIVERS2=$(docker exec spark-worker-2 find /opt/spark/work -name "stderr" 2>/dev/null | wc -l)
  if [ "$DRIVERS2" -gt "0" ]; then
    echo "✅ Spark en modo CLUSTER - driver corriendo en worker ($DRIVERS2 drivers encontrados)"
  else
    echo "⚠️  No se detectó driver en workers"
  fi
fi

# 9. Flask
echo ""
echo "=== FLASK ==="
curl -s http://localhost:5001 | grep -q "Agile" && echo "✅ Flask OK" || echo "❌ Flask ERROR"

# 10. Airflow + DAG
echo ""
echo "=== AIRFLOW + ENTRENAMIENTO AUTOMÁTICO ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8085)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
  echo "✅ Airflow UI OK (http://localhost:8085)"
else
  echo "❌ Airflow UI no responde (HTTP $HTTP_CODE)"
fi

DAG_EXISTS=$(docker exec airflow airflow dags list 2>/dev/null | grep "flight_delay_model_training")
if [ -n "$DAG_EXISTS" ]; then
  echo "✅ DAG 'flight_delay_model_training' registrado en Airflow"
else
  echo "❌ DAG no encontrado"
fi

IMPORT_ERRORS=$(docker exec airflow airflow dags list-import-errors 2>/dev/null | grep "flight_delay_model_training")
if [ -z "$IMPORT_ERRORS" ]; then
  echo "✅ DAG sin errores de importación"
else
  echo "❌ Errores de importación en el DAG: $IMPORT_ERRORS"
fi

LAST_SUCCESS=$(docker exec airflow airflow dags list-runs -d flight_delay_model_training 2>/dev/null | grep "success" | head -1)
if [ -n "$LAST_SUCCESS" ]; then
  LAST_DATE=$(echo "$LAST_SUCCESS" | awk '{print $5}')
  echo "✅ Entrenamiento completado con éxito (último run: $LAST_DATE)"
else
  echo "⚠️  No hay runs exitosos aún - lanzando entrenamiento..."
  docker exec airflow airflow dags trigger flight_delay_model_training 2>/dev/null
  echo "   DAG triggered - tardará ~3 min. Comprueba en http://localhost:8085"
fi

MODELS_COUNT=$(docker exec minio mc ls local/lakehouse/models/ 2>/dev/null | grep -c "bin")
if [ "$MODELS_COUNT" -gt "0" ]; then
  echo "✅ Modelos en MinIO/Lakehouse: $MODELS_COUNT ficheros .bin"
else
  echo "⚠️  No se encontraron modelos en s3a://lakehouse/models/"
fi

# 11. Observabilidad (¡Actualizado con comprobaciones de Provisioning!)
echo ""
echo "=== OBSERVABILIDAD ==="
curl -s http://localhost:9090/-/ready 2>/dev/null | grep -q "Ready" && echo "✅ Prometheus OK (http://localhost:9090)" || echo "❌ Prometheus ERROR"

HTTP_KAFKAUI=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090)
[ "$HTTP_KAFKAUI" = "200" ] && echo "✅ Kafka UI OK (http://localhost:8090)" || echo "❌ Kafka UI ERROR"

HTTP_GRAFANA=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
if [ "$HTTP_GRAFANA" = "200" ] || [ "$HTTP_GRAFANA" = "302" ]; then
  echo "✅ Grafana UI OK (http://localhost:3000)"
  
  # Verificar si el Datasource de Prometheus fue inyectado por Provisioning
  DS_CHECK=$(curl -s -u admin:admin http://localhost:3000/api/datasources/name/Prometheus 2>/dev/null | grep -o '"name":"Prometheus"')
  if [ "$DS_CHECK" = '"name":"Prometheus"' ]; then
    echo "   ↳ ✅ Datasource 'Prometheus' detectado correctamente"
  else
    echo "   ↳ ❌ ERROR: El datasource 'Prometheus' no se ha provisionado"
  fi

  # Verificar si el Dashboard fue inyectado por Provisioning
  DB_CHECK=$(curl -s -u admin:admin http://localhost:3000/api/search 2>/dev/null | grep -o "Docker Containers - Practica Creativa")
  if [ -n "$DB_CHECK" ]; then
    echo "   ↳ ✅ Dashboard 'Docker Containers' cargado con éxito"
  else
    echo "   ↳ ❌ ERROR: El Dashboard no se encuentra en las rutas de provisioning"
  fi
else
  echo "❌ Grafana UI ERROR (No responde en el puerto 3000)"
fi

# 12. MLflow
echo ""
echo "=== MLFLOW ==="
curl -s http://localhost:5000/health 2>/dev/null | grep -q "OK" && echo "✅ MLflow OK (http://localhost:5000)" || echo "❌ MLflow ERROR"

# 13. Test predicción end-to-end
echo ""
echo "=== TEST PREDICCIÓN END-TO-END ==="
echo "⏳ Enviando petición de predicción..."
RESPONSE=$(curl -s -X POST http://localhost:5001/flights/delays/predict/classify_realtime \
  -d "DepDelay=5&Carrier=AA&FlightDate=2016-12-25&Origin=ATL&Dest=SFO&FlightNum=1519")
UUID=$(echo $RESPONSE | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['id'])" 2>/dev/null)
echo "UUID generado: $UUID"

echo "⏳ Esperando predicción de Spark (50s en modo cluster)..."
sleep 50

PREDICTION=$(docker exec mongo mongo agile_data_science --eval "db.flight_delay_ml_response.find({UUID:'$UUID'}).limit(1).toArray()" 2>/dev/null | grep "Prediction")
if [ -n "$PREDICTION" ]; then
  echo "✅ Predicción recibida en MongoDB: $PREDICTION"
else
  echo "⚠️  Predicción no encontrada aún en MongoDB"
fi

CASS_PREDICTION=$(docker exec -i cassandra cqlsh -e "SELECT prediction FROM agile_data_science.flight_delay_ml_response WHERE uuid='$UUID';" 2>/dev/null | grep -E "[0-9]")
if [ -n "$CASS_PREDICTION" ]; then
  echo "✅ Predicción recibida en Cassandra: $CASS_PREDICTION"
else
  echo "⚠️  Predicción no encontrada aún en Cassandra"
fi

echo ""
echo "========================================"
echo "           RESUMEN DE ACCESOS"
echo "========================================"
echo "🌐 Web predicción:  http://localhost:5001/flights/delays/predict_kafka"
echo "📊 Spark UI:        http://localhost:8080"
echo "🗄️  MinIO UI:        http://localhost:9001  (minioadmin/minioadmin)"
echo "📈 MLflow:          http://localhost:5000"
echo "✈️  Airflow:         http://localhost:8085  (admin/admin)"
echo "🔥 Kafka UI:        http://localhost:8090"
echo "📡 Prometheus:      http://localhost:9090"
echo "📉 Grafana:         http://localhost:3000  (admin/admin)"
echo "========================================"
echo ""
echo "✅ Sistema listo!"
