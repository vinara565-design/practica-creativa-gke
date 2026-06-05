# Práctica Creativa - Predicción de Retrasos de Vuelos en Tiempo Real

**Raúl  Villa Navarro y Fernando Ruiz Haro**

Infraestructura Big Data completa y robusta desplegada en producción sobre **Google Kubernetes Engine (GKE)**, utilizando arquitecturas orientadas a eventos, procesamiento distribuido y almacenamiento persistente resiliente.

---

##  Endpoints de Acceso en Producción (GKE)

Los servicios se encuentran actualmente expuestos de forma pública en Google Cloud a través de balanceadores de carga (`LoadBalancer`). Puede acceder a las interfaces de monitorización y ejecución mediante las siguientes direcciones:

| Servicio | URL de Acceso | Credenciales |
| :--- | :--- | :--- |
| **Frontend Web (Flask)** | `http://35.195.202.35:5001/flights/delays/predict_kafka` | Acceso Libre |
| **Kafka UI** | `http://34.156.175.7:8090` | Acceso Libre |
| **MLflow Tracking** | `http://34.77.1.230:5000` | Acceso Libre |
| **Grafana Dashboards** | `http://34.78.106.44:3000` | `admin` / `admin` |

---

##  Requisitos del Entorno e Infraestructura Cloud

Para garantizar el correcto funcionamiento del pipeline y soportar la carga analítica distribuida, la arquitectura se ha desplegado bajo las siguientes especificaciones en **Google Cloud Platform (GCP)**:

### 1. Máquina de Desarrollo / Bastion Host (Ubuntu)
Entorno utilizado para la compilación del artefacto de Scala, construcción de imágenes Docker y gestión del clúster mediante herramientas CLI.
* **Sistema Operativo:** Ubuntu Server 20.04 / 22.04 LTS
* **Hardware Mínimo:** 4 vCPUs y 16 GB de Memoria RAM (Tipo de máquina sugerido: `e2-standard-4`)
* **Automatización:** Se incluye un script `.sh` en la raíz encargado de automatizar la instalación limpia de todas las versiones de las herramientas del sistema (Java, Scala, SBT, Docker, Docker Compose, `gcloud` CLI y `kubectl`).

### 2. Clúster de Producción (Google Kubernetes Engine - GKE)
* **Topología:** Clúster administrado de **3 Nodos Activos**.
* **Región/Zona de Despliegue:** `europe-west1-b` (Bélgica).
* **Asignación de Recursos:** Nodos dimensionados para garantizar la ejecución concurrente de los motores de Spark (Master/Workers), brokers de mensajería, bases de datos (Cassandra, MongoDB) y stacks de observabilidad.

---

##  Arquitectura del Sistema

* **Ingesta Activa:** Cliente Web Flask integrado con WebSockets acoplado a un clúster de **Apache Kafka**.
* **Procesamiento Stream:** **Apache Spark** (1 Master + 2 Workers) ejecutando la lógica de predicción en tiempo real en modo Clúster.
* **Capa de Datos Dual:** **Apache Cassandra** (distancias origen-destino y respuestas ML) y **MongoDB** (historial de predicciones), respaldados por **Persistent Volume Claims (PVC)** en Google Cloud.
* **Orquestación y MLOps:** Pipeline de reentrenamiento semanal automatizado en **Apache Airflow** conectado a un Lakehouse centralizado en **MinIO** (S3 compatible).
* **Observabilidad:** Recolección de métricas con **Prometheus** y visualización mediante dashboards provisionados automáticamente en **Grafana**.

---

##  Mejoras Adicionales Implementadas

* **Orquestación (Apache Airflow):** Pipeline semanal automatizado (`training_dag.py`) para el reentrenamiento del modelo ML sin interrupciones de servicio.
* **Ciclo de Vida ML (MLflow):** Tracking completo de experimentos, métricas, parámetros y registro formal de modelos bajo el experimento `flight_delay_prediction`.
* **Lakehouse Centralizado (MinIO):** Repositorio S3-compatible para el almacenamiento persistente de los binarios del modelo entrenado.
* **Monitorización y Observabilidad:** Stack **Prometheus** + **Grafana** con dashboards provisionados automáticamente para la supervisión en tiempo real del clúster.
* **Administración de Mensajería:** Interfaz **Kafka UI** para inspección del flujo de tópicos.
* **Despliegue en GKE:** Toda la infraestructura migrada y operativa en Google Kubernetes Engine con almacenamiento persistente en disco de Google Cloud.

---

##  Notas de Despliegue

La infraestructura actual se encuentra completamente operativa en GKE (ver endpoints arriba). Los manifiestos de Kubernetes están disponibles en el directorio `k8s/` y las imágenes Docker custom en `dockerfiles/`.

Para un redespliegue completo se requeriría:
1. Preparar el entorno de desarrollo ejecutando el script de instalación automatizado de versiones.
2. **Compilar el JAR de Scala:** `sbt package` en `flight_prediction/`
3. **Construir y publicar las imágenes Docker custom:** (`Dockerfile.flask`, `Dockerfile.spark`, `Dockerfile.airflow`)
4. **Aplicar los manifiestos en orden:** bases de datos ➡️ Spark ➡️ Flask ➡️ observabilidad ➡️ orquestación
5. **Ejecutar el script de inicialización:** `./k8s/init_k8s.sh` para cargar datos iniciales en Cassandra y MinIO.

---

## ⚠️ Notas Técnicas

* **Scripts en el directorio raíz:** Los ficheros `start_and_verify.sh` e `iniciar_datos.sh` corresponden al histórico de pruebas realizadas sobre contenedores Docker locales y simulaciones en Minikube durante la fase de diseño. No intervienen en la orquestación actual de la infraestructura en GKE.
* **Persistencia de datos:** Las bases de datos utilizan **Persistent Volume Claims (PVC)** en Google Cloud. Toda la carga inicial de datos (distancias de Cassandra y modelos en MinIO) ya se encuentra inyectada de forma permanente en los discos del clúster de producción.