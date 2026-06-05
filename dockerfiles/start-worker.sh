#!/bin/bash
/opt/spark/sbin/start-worker.sh spark://spark-master:7077
tail -f /opt/spark/logs/*.out
