#!/bin/bash
set -e

cd /opt/AI_World

echo "=== Pulling latest main ==="
git checkout main
git pull origin main

echo "=== Stopping old container ==="
docker rm -f ai-world-api 2>/dev/null || true

echo "=== Building backend ==="
docker build -t ai-world-api:latest ./server

echo "=== Starting FAKE backend ==="
docker run -d \
  --name ai-world-api \
  --restart unless-stopped \
  -p 8000:8000 \
  -e AI_PROVIDER=fake \
  -e CORS_ORIGINS="https://pfalli.github.io" \
  ai-world-api:latest

echo "=== Waiting for API ==="
sleep 3

curl --fail http://127.0.0.1:8000/health

echo
echo "AI World backend running with FAKE provider."
docker ps --filter name=ai-world-api