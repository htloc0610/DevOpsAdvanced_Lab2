pipeline {
    agent { label 'built-in' }
    
    environment {
        // SonarQube Configuration
        SONARQUBE_URL = 'http://35.225.11.231:9000'
        SONAR_PROJECT_KEY = 'spring-petclinic-microservices'
        SONAR_TOKEN = credentials('sonarqube-token')
        
        // Docker Configuration
        DOCKER_USERNAME = credentials('dockerhub-username')
        DOCKER_PASSWORD = credentials('dockerhub-password')
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        // Maven Docker Image
        MAVEN_IMAGE = 'maven:3.9.6-eclipse-temurin-17'
        
        // Services list
        ALL_SERVICES = 'spring-petclinic-api-gateway,spring-petclinic-customers-service,spring-petclinic-vets-service,spring-petclinic-visits-service,spring-petclinic-genai-service,spring-petclinic-config-server,spring-petclinic-discovery-server,spring-petclinic-admin-server'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }
        
        stage('Detect Changes') {
            steps {
                script {
                    def isPR = env.CHANGE_ID != null
                    
                    if (!isPR) {
                        // Regular branch build - always build all services
                        echo "Branch build detected - building all services"
                        env.AFFECTED_SERVICES = env.ALL_SERVICES
                        return
                    }
                    
                    // Pull Request - detect changes
                    echo "PR #${env.CHANGE_ID} detected (target: ${env.CHANGE_TARGET})"
                    echo 'Analyzing changed files...'
                    
                    def changes = ''
                    try {
                        changes = sh(script: "git diff --name-only origin/${env.CHANGE_TARGET}...HEAD", returnStdout: true).trim()
                    } catch (Exception e) {
                        echo "Error detecting changes, building all services: ${e.message}"
                        env.AFFECTED_SERVICES = env.ALL_SERVICES
                        return
                    }
                    
                    echo "Files changed:\n${changes}"
                    
                    def servicesList = env.ALL_SERVICES.split(',')
                    def affectedServices = []
                    
                    // Check if pom.xml or root files changed - rebuild all
                    if (changes.contains('pom.xml') || changes.contains('docker/Dockerfile')) {
                        echo "Core files changed (pom.xml or Dockerfile) - rebuilding all services"
                        affectedServices = servicesList
                    } else {
                        // Detect affected services based on changed paths
                        affectedServices = changes.tokenize("\n")
                            .collect { 
                                def matcher = (it =~ /^([^\/]+)\//)
                                matcher ? matcher[0][1] : null 
                            }
                            .unique()
                            .findAll { it in servicesList }
                    }
                    
                    if (affectedServices.isEmpty()) {
                        echo "No service changes detected in PR - skipping build stages"
                        env.AFFECTED_SERVICES = ''
                    } else {
                        env.AFFECTED_SERVICES = affectedServices.join(',')
                        echo "Services to build for PR: ${env.AFFECTED_SERVICES}"
                    }
                }
            }
        }
        
        stage('Build & Test') {
            when {
                expression { env.AFFECTED_SERVICES && env.AFFECTED_SERVICES != '' }
            }
            steps {
                script {
                    echo 'Building and testing with Maven in Docker container...'
                    def services = env.AFFECTED_SERVICES.split(',')
                    
                    // Build parent pom first if needed
                    sh """
                        docker run --rm \
                            -v \$(pwd):/workspace \
                            -v \$HOME/.m2:/root/.m2 \
                            -w /workspace \
                            ${MAVEN_IMAGE} \
                            mvn clean install -N -DskipTests
                    """
                    
                    // Build each affected service
                    services.each { service ->
                        echo "Building and testing ${service}..."
                        sh """
                            docker run --rm \
                                -v \$(pwd):/workspace \
                                -v \$HOME/.m2:/root/.m2 \
                                -w /workspace/${service} \
                                ${MAVEN_IMAGE} \
                                mvn clean verify -DskipTests=false
                        """
                    }
                }
            }
        }
        
        stage('SonarQube Analysis') {
            when {
                expression { env.AFFECTED_SERVICES && env.AFFECTED_SERVICES != '' }
            }
            steps {
                echo 'Running SonarQube code analysis in Docker container...'
                withSonarQubeEnv('SonarQube') {
                    sh """
                        docker run --rm \
                            -v \$(pwd):/workspace \
                            -v \$HOME/.m2:/root/.m2 \
                            -w /workspace \
                            -e SONAR_HOST_URL=${SONARQUBE_URL} \
                            ${MAVEN_IMAGE} \
                            mvn sonar:sonar \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.host.url=${SONARQUBE_URL} \
                                -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }
        
        stage('Quality Gate') {
            when {
                expression { env.AFFECTED_SERVICES && env.AFFECTED_SERVICES != '' }
            }
            steps {
                echo 'Waiting for SonarQube Quality Gate...'
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        
        stage('Build Docker Images') {
            when {
                expression { env.AFFECTED_SERVICES && env.AFFECTED_SERVICES != '' }
            }
            steps {
                echo 'Building Docker images for affected microservices...'
                script {
                    def serviceConfigs = [
                        'spring-petclinic-api-gateway': '8080',
                        'spring-petclinic-customers-service': '8081',
                        'spring-petclinic-vets-service': '8083',
                        'spring-petclinic-visits-service': '8082',
                        'spring-petclinic-genai-service': '8084',
                        'spring-petclinic-config-server': '8888',
                        'spring-petclinic-discovery-server': '8761',
                        'spring-petclinic-admin-server': '9090'
                    ]
                    
                    def services = env.AFFECTED_SERVICES.split(',')
                    
                    services.each { service ->
                        def port = serviceConfigs[service]
                        echo "Building Docker image for ${service}..."
                        sh """
                            docker build \
                                -f docker/Dockerfile \
                                --build-arg ARTIFACT_NAME=${service}-4.0.1 \
                                --build-arg EXPOSED_PORT=${port} \
                                --platform linux/amd64 \
                                -t ${DOCKER_USERNAME}/${service}:${DOCKER_TAG} \
                                -t ${DOCKER_USERNAME}/${service}:latest \
                                ./${service}/target/
                        """
                    }
                }
            }
        }
        
        stage('Push to DockerHub') {
            when {
                expression { env.AFFECTED_SERVICES && env.AFFECTED_SERVICES != '' }
            }
            steps {
                echo 'Pushing Docker images to DockerHub...'
                script {
                    // Login to DockerHub
                    sh """
                        echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
                    """
                    
                    def services = env.AFFECTED_SERVICES.split(',')
                    
                    services.each { service ->
                        echo "Pushing ${service}..."
                        sh """
                            docker push ${DOCKER_USERNAME}/${service}:${DOCKER_TAG}
                            docker push ${DOCKER_USERNAME}/${service}:latest
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            script {
                if (env.AFFECTED_SERVICES && env.AFFECTED_SERVICES != '') {
                    echo "Pipeline completed successfully!"
                    echo "Built and pushed services: ${env.AFFECTED_SERVICES}"
                    echo "Docker images tagged with: ${DOCKER_TAG} and latest"
                } else {
                    echo "Pipeline completed - no services needed rebuilding"
                }
            }
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            echo 'Cleaning up...'
            // Clean up Docker images to save space (optional)
            sh '''
                docker image prune -f || true
            '''
        }
    }
}
