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
cat > /opt/app/docker-compose.yml <<'EOF'
version: "3.8"

services:
  frontend:
    image: ${dockerhub_username}/student-frontend:${image_tag}
    container_name: frontend
    restart: always
    environment:
      - PORT=3000
      - BACKEND_URL=http://${backend_private_ip}:5000
      - APP_ENV=${environment}
    ports:
      - "80:3000"
EOF

cd /opt/app
docker compose pull
docker compose up -d
