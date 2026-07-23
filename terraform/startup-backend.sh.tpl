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
  mongo:
    image: mongo:7
    container_name: mongo
    restart: always
    volumes:
      - mongo_data:/data/db
    ports:
      - "27017:27017"
    networks:
      - backend_net

  backend:
    image: ${dockerhub_username}/student-backend:${image_tag}
    container_name: backend
    restart: always
    depends_on:
      - mongo
    environment:
      - PORT=5000
      - MONGO_URI=mongodb://mongo:27017/studentdb
      - APP_ENV=${environment}
    ports:
      - "5000:5000"
    networks:
      - backend_net

volumes:
  mongo_data:

networks:
  backend_net:
    driver: bridge
EOF

cd /opt/app
docker compose pull
docker compose up -d
