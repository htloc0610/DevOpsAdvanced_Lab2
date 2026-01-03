@echo off
REM Script to build and push all Spring PetClinic microservices Docker images
REM Usage: build-and-push.bat [docker-username] [tag]
REM Example: build-and-push.bat anwirisme main

setlocal enabledelayedexpansion

REM Configuration
set DOCKER_USERNAME=%1
if "%DOCKER_USERNAME%"=="" set DOCKER_USERNAME=anwirisme

set TAG=%2
if "%TAG%"=="" set TAG=main

echo ==========================================
echo Building and Pushing PetClinic Images
echo Docker Username: %DOCKER_USERNAME%
echo Tag: %TAG%
echo ==========================================

REM Step 1: Clean and build all services with Maven
echo.
echo Step 1: Building all services with Maven...
call mvn clean install -DskipTests -Pbuildocker
if errorlevel 1 (
    echo ERROR: Maven build failed!
    exit /b 1
)

REM Step 2: Build Docker images for each service
echo.
echo Step 2: Building Docker images...

set SERVICES=spring-petclinic-api-gateway spring-petclinic-customers-service spring-petclinic-vets-service spring-petclinic-visits-service spring-petclinic-genai-service spring-petclinic-config-server spring-petclinic-discovery-server spring-petclinic-admin-server

for %%S in (%SERVICES%) do (
    echo.
    echo Building %%S...
    
    REM Determine the exposed port based on service
    set EXPOSED_PORT=8080
    if "%%S"=="spring-petclinic-api-gateway" set EXPOSED_PORT=8080
    if "%%S"=="spring-petclinic-customers-service" set EXPOSED_PORT=8081
    if "%%S"=="spring-petclinic-vets-service" set EXPOSED_PORT=8083
    if "%%S"=="spring-petclinic-visits-service" set EXPOSED_PORT=8082
    if "%%S"=="spring-petclinic-genai-service" set EXPOSED_PORT=8084
    if "%%S"=="spring-petclinic-config-server" set EXPOSED_PORT=8888
    if "%%S"=="spring-petclinic-discovery-server" set EXPOSED_PORT=8761
    if "%%S"=="spring-petclinic-admin-server" set EXPOSED_PORT=9090
    
    REM Build Docker image
    docker build -f docker/Dockerfile --build-arg ARTIFACT_NAME=%%S-4.0.1 --build-arg EXPOSED_PORT=!EXPOSED_PORT! --platform linux/amd64 -t %DOCKER_USERNAME%/%%S:%TAG% ./%%S/target/
    if errorlevel 1 (
        echo ERROR: Docker build failed for %%S!
        exit /b 1
    )
)

REM Step 3: Push all images to Docker Hub
echo.
echo Step 3: Pushing images to Docker Hub...
echo Please make sure you are logged in to Docker Hub (docker login)
pause

for %%S in (%SERVICES%) do (
    echo.
    echo Pushing %DOCKER_USERNAME%/%%S:%TAG%...
    docker push %DOCKER_USERNAME%/%%S:%TAG%
    if errorlevel 1 (
        echo ERROR: Docker push failed for %%S!
        exit /b 1
    )
)

echo.
echo ==========================================
echo All images built and pushed successfully!
echo ==========================================
echo.
echo Images pushed:
for %%S in (%SERVICES%) do (
    echo   - %DOCKER_USERNAME%/%%S:%TAG%
)

endlocal
