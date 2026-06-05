#!/bin/bash
/opt/spark/sbin/start-master.sh
tail -f /opt/spark/logs/*.out
