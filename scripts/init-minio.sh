#!/bin/bash
set -e

# Wait for MinIO to be available
echo "Waiting for MinIO to be available..."
until curl -s http://minio:9000/minio/health/live > /dev/null; do
  sleep 1
done

# Create the bucket using MinIO client
mc config host add myminio http://minio:9000 minioadmin minioadmin
mc mb myminio/flowdose --region us-east-1
mc anonymous set download myminio/flowdose
mc anonymous set public myminio/flowdose

echo "MinIO initialization complete!" 