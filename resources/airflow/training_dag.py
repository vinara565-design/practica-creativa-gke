from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2026, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'flight_delay_model_training',
    default_args=default_args,
    description='Entrena el modelo en el cluster Spark leyendo de MinIO/Lakehouse con Iceberg',
    schedule_interval='@weekly',
    catchup=False,
) as dag:

    train_model = BashOperator(
        task_id='train_model_spark_cluster',
        append_env=True,
        bash_command="""
            export DRIVER_IP=$(hostname -i | awk '{print $1}')
            spark-submit \
                --master spark://spark-master-svc:7077 \
                --deploy-mode client \
                --conf spark.driver.host=${DRIVER_IP} \
                --conf spark.driver.bindAddress=0.0.0.0 \
                --conf spark.driver.port=37100 \
                --conf spark.blockManager.port=37101 \
                --conf spark.ui.port=37102 \
                --packages org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262,org.apache.iceberg:iceberg-spark-runtime-4.1_2.13:1.11.0 \
                --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
                --conf spark.sql.catalog.lakehouse=org.apache.iceberg.spark.SparkCatalog \
                --conf spark.sql.catalog.lakehouse.type=hadoop \
                --conf spark.sql.catalog.lakehouse.warehouse=s3a://lakehouse/iceberg_warehouse \
                --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
                --conf spark.hadoop.fs.s3a.access.key=minioadmin \
                --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
                --conf spark.hadoop.fs.s3a.path.style.access=true \
                --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
                --conf spark.hadoop.fs.s3a.aws.credentials.provider=org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider \
                --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false \
                --conf spark.executor.memory=512m \
                --conf spark.pyspark.python=python3 \
                /opt/airflow/dags/train_spark_mllib_model.py s3a://lakehouse
        """,
        env={
            'MODELS_PATH': 's3a://lakehouse/models',
            'MINIO_ENDPOINT': 'http://minio:9000',
            'MINIO_ACCESS_KEY': 'minioadmin',
            'MINIO_SECRET_KEY': 'minioadmin',
            'TRAINING_DATA_PATH': 's3a://lakehouse/raw/flights/simple_flight_delay_features.jsonl',
            'MLFLOW_TRACKING_URI': 'http://mlflow-svc:5000',
            'JAVA_HOME': '/usr/lib/jvm/java-17-openjdk-amd64',
            'SPARK_HOME': '/opt/spark',
            'PATH': '/opt/spark/bin:/usr/local/bin:/usr/bin:/bin',
        },
    )
