#!/bin/bash
set -e

# Install Docker
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
fi

# Install docker-compose plugin
if ! docker compose version &> /dev/null; then
  apt-get update -y
  apt-get install -y docker-compose-plugin
fi

mkdir -p /opt/app
cat > /opt/app/docker-compose.yml <<'EOF2'
services:
  backend:
    image: ${dockerhub_username}/student-backend:${image_tag}
    container_name: backend
    restart: always
    environment:
      - PORT=5000
      - MONGO_URI=${mongo_uri}
      - APP_ENV=${environment}
    ports:
      - "5000:5000"
EOF2

cd /opt/app
docker compose pull
docker compose up -d
