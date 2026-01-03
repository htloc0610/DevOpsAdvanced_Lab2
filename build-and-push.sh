#!/bin/bash

# Script to build and push all Spring PetClinic microservices Docker images
# Usage: ./build-and-push.sh [docker-username] [tag]
# Example: ./build-and-push.sh anwirisme main

set -e  # Exit on error

# Configuration
DOCKER_USERNAME=${1:-anwirisme}
TAG=${2:-main}

echo "=========================================="
echo "Building and Pushing PetClinic Images"
echo "Docker Username: $DOCKER_USERNAME"
echo "Tag: $TAG"
echo "=========================================="

# Step 1: Clean and build all services with Maven
echo ""
echo "Step 1: Building all services with Maven..."
mvn clean install -DskipTests -Pbuildocker

# Step 2: Build Docker images for each service
echo ""
echo "Step 2: Building Docker images..."

SERVICES=(
    "spring-petclinic-api-gateway"
    "spring-petclinic-customers-service"
    "spring-petclinic-vets-service"
    "spring-petclinic-visits-service"
    "spring-petclinic-genai-service"
    "spring-petclinic-config-server"
    "spring-petclinic-discovery-server"
    "spring-petclinic-admin-server"
)

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "Building $SERVICE..."
    
    # Determine the exposed port based on service
    case $SERVICE in
        "spring-petclinic-api-gateway")
            EXPOSED_PORT=8080
            ;;
        "spring-petclinic-customers-service")
            EXPOSED_PORT=8081
            ;;
        "spring-petclinic-vets-service")
            EXPOSED_PORT=8083
            ;;
        "spring-petclinic-visits-service")
            EXPOSED_PORT=8082
            ;;
        "spring-petclinic-genai-service")
            EXPOSED_PORT=8084
            ;;
        "spring-petclinic-config-server")
            EXPOSED_PORT=8888
            ;;
        "spring-petclinic-discovery-server")
            EXPOSED_PORT=8761
            ;;
        "spring-petclinic-admin-server")
            EXPOSED_PORT=9090
            ;;
    esac
    
    # Build Docker image
    docker build \
        -f docker/Dockerfile \
        --build-arg ARTIFACT_NAME=$SERVICE-4.0.1 \
        --build-arg EXPOSED_PORT=$EXPOSED_PORT \
        --platform linux/amd64 \
        -t $DOCKER_USERNAME/$SERVICE:$TAG \
        ./$SERVICE/target/
done

# Step 3: Push all images to Docker Hub
echo ""
echo "Step 3: Pushing images to Docker Hub..."
echo "Please make sure you are logged in to Docker Hub (docker login)"
read -p "Press Enter to continue with push, or Ctrl+C to cancel..."

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "Pushing $DOCKER_USERNAME/$SERVICE:$TAG..."
    docker push $DOCKER_USERNAME/$SERVICE:$TAG
done

echo ""
echo "=========================================="
echo "✅ All images built and pushed successfully!"
echo "=========================================="
echo ""
echo "Images pushed:"
for SERVICE in "${SERVICES[@]}"; do
    echo "  - $DOCKER_USERNAME/$SERVICE:$TAG"
done
