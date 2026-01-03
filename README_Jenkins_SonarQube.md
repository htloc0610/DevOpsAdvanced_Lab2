# Jenkins CI/CD Pipeline with SonarQube Integration

## Overview

This document describes the Jenkins CI/CD pipeline configuration for the Spring PetClinic Microservices project with integrated SonarQube SAST (Static Application Security Testing) code analysis.

## Architecture

The pipeline uses Docker containers for Maven builds to avoid conflicts with the Jenkins host system's Maven/JDK installation. All 8 microservices are built, analyzed, and deployed:

- spring-petclinic-api-gateway
- spring-petclinic-customers-service
- spring-petclinic-vets-service
- spring-petclinic-visits-service
- spring-petclinic-genai-service
- spring-petclinic-config-server
- spring-petclinic-discovery-server
- spring-petclinic-admin-server

## Prerequisites

### 1. Jenkins Installation

Ensure Jenkins is installed with the following plugins:
- **Pipeline**: For declarative pipeline support
- **Docker Pipeline**: For Docker agent support
- **SonarQube Scanner**: For SonarQube integration
- **Git**: For source code management
- **Credentials Binding**: For secure credential management

### 2. Docker on Jenkins Host

Jenkins must have access to Docker daemon to use Docker agents and build images:
```bash
# Verify Docker is accessible
docker --version
docker ps

# Add Jenkins user to docker group (Linux)
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### 3. SonarQube Server

- **URL**: `http://your-sonarqube-server:9000` (example: `http://sonarqube.example.com:9000`)
- **Project Key**: `spring-petclinic-microservices`
- Authentication token will be configured as Jenkins credential

## Jenkins Configuration

### Step 1: Configure SonarQube Server in Jenkins

1. Navigate to **Manage Jenkins** → **Configure System**
2. Scroll to **SonarQube servers** section
3. Click **Add SonarQube**
4. Configure:
   - **Name**: `SonarQube` (must match the name used in Jenkinsfile)
   - **Server URL**: `http://your-sonarqube-server:9000`
   - **Server authentication token**: Select the credential (see Step 2)
5. Click **Save**

### Step 2: Add Jenkins Credentials

Navigate to **Manage Jenkins** → **Manage Credentials** → **Global** → **Add Credentials**

#### 2.1 SonarQube Token
- **Kind**: Secret text
- **Scope**: Global
- **Secret**: `<your-sonarqube-token>`
- **ID**: `sonarqube-token`
- **Description**: SonarQube authentication token

#### 2.2 DockerHub Username
- **Kind**: Secret text
- **Scope**: Global
- **Secret**: `<your-dockerhub-username>`
- **ID**: `dockerhub-username`
- **Description**: DockerHub username

#### 2.3 DockerHub Password
- **Kind**: Secret text
- **Scope**: Global
- **Secret**: `<your-dockerhub-password-or-token>`
- **ID**: `dockerhub-password`
- **Description**: DockerHub password or access token

### Step 3: Create Pipeline Job

1. Go to Jenkins dashboard
2. Click **New Item**
3. Enter job name: `spring-petclinic-microservices`
4. Select **Pipeline**
5. Click **OK**

### Step 4: Configure Pipeline

In the pipeline configuration:

1. **General Section**:
   - ☑ Discard old builds (keep last 10 builds)
   - Description: "CI/CD pipeline for Spring PetClinic Microservices with SonarQube SAST"

2. **Build Triggers** (optional):
   - ☑ Poll SCM: `H/5 * * * *` (poll every 5 minutes)
   - Or configure GitHub webhook for automatic builds

3. **Pipeline Section**:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `<your-git-repository-url>`
   - **Credentials**: Select Git credentials if private repo
   - **Branch**: `*/main` (or your default branch)
   - **Script Path**: `Jenkinsfile`

4. Click **Save**

## Pipeline Stages Explanation

### 1. Checkout
Clones the source code from the Git repository.

### 2. Build & Test
- Uses Maven Docker container (`maven:3.9.6-eclipse-temurin-17`)
- Runs `mvn clean verify` to compile, test, and package all microservices
- Mounts Maven local repository for dependency caching
- Jacoco code coverage is collected during this phase

### 3. SonarQube Analysis
- Uses Maven Docker container
- Executes SonarQube scanner via Maven plugin
- Scans all 8 modules for:
  - **Bugs**: Code defects that may cause incorrect behavior
  - **Vulnerabilities**: Security weaknesses
  - **Code Smells**: Maintainability issues
  - **Coverage**: Test coverage metrics
  - **Duplications**: Duplicated code blocks

### 4. Quality Gate
- Waits for SonarQube to process analysis results
- Checks if code meets quality gate conditions
- **Aborts pipeline if quality gate fails**
- Timeout: 5 minutes

### 5. Build Docker Images
- Builds Docker images for all 8 microservices
- Uses `docker/Dockerfile` with appropriate build arguments
- Tags images with:
  - Build number: `${BUILD_NUMBER}`
  - Latest tag: `latest`
- Platform: `linux/amd64`

### 6. Push to DockerHub
- Authenticates with DockerHub using credentials
- Pushes all images with both tags (build number and latest)
- Images available at: `<dockerhub-username>/<service-name>:<tag>`

## Running the Pipeline

### Trigger Build Manually
1. Go to the pipeline job
2. Click **Build Now**
3. Monitor progress in **Build History**
4. Click on build number → **Console Output** for detailed logs

### Automatic Triggers
- **Git Webhook**: Configure webhook in Git repository settings
- **SCM Polling**: Already configured to poll every 5 minutes
- **Upstream Jobs**: Can be triggered by other Jenkins jobs

## Viewing Results

### Jenkins Build Results
- **Console Output**: Full build logs
- **Test Results**: JUnit test reports (if configured)
- **Artifacts**: Built JAR files (if archived)

### SonarQube Dashboard
1. Open browser: `http://your-sonarqube-server:9000`
2. Navigate to project: `spring-petclinic-microservices`
3. View:
   - **Overview**: Quality gate status, coverage, issues summary
   - **Issues**: Detailed list of bugs, vulnerabilities, code smells
   - **Measures**: Metrics and code coverage
   - **Code**: Browse source code with highlighted issues
   - **Activity**: Analysis history

### DockerHub
1. Login to DockerHub: `https://hub.docker.com`
2. Navigate to your repositories
3. Verify images are pushed with correct tags

## Troubleshooting

### Issue: Docker Permission Denied
**Error**: `Got permission denied while trying to connect to the Docker daemon socket`

**Solution**:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Issue: SonarQube Quality Gate Timeout
**Error**: `Quality Gate timeout after 5 minutes`

**Solution**:
- Check SonarQube server is running and accessible
- Increase timeout in Jenkinsfile: `timeout(time: 10, unit: 'MINUTES')`
- Check SonarQube compute engine for processing queue

### Issue: Maven Build Fails in Docker
**Error**: `Cannot resolve dependencies`

**Solution**:
- Ensure Maven local repository is mounted: `-v $HOME/.m2:/root/.m2`
- Check network connectivity from Docker containers
- Clear Maven cache: `rm -rf ~/.m2/repository`

### Issue: DockerHub Authentication Failed
**Error**: `unauthorized: authentication required`

**Solution**:
- Verify DockerHub credentials in Jenkins
- Use access token instead of password (recommended)
- Check credential IDs match Jenkinsfile: `dockerhub-username` and `dockerhub-password`

### Issue: Quality Gate Fails
**Error**: Pipeline aborted due to quality gate failure

**Solution**:
- Review SonarQube issues and fix critical problems
- Adjust quality gate conditions in SonarQube project settings (if appropriate)
- Use `abortPipeline: false` in Jenkinsfile to continue despite failures (not recommended)

## SonarQube Quality Gate Configuration

To configure quality gate in SonarQube:

1. Login to SonarQube as admin
2. Go to **Quality Gates**
3. Create new or edit existing gate
4. Set conditions (examples):
   - Coverage: ≥ 80%
   - Bugs: = 0
   - Vulnerabilities: = 0
   - Code Smells: ≤ 10
   - Duplicated Lines: ≤ 3%
5. Assign to project: `spring-petclinic-microservices`

## Customization

### Change Docker Registry
To use a different Docker registry (e.g., AWS ECR, Harbor):

1. Update credentials in Jenkins
2. Modify Jenkinsfile:
   ```groovy
   DOCKER_REGISTRY = 'your-registry.example.com'
   DOCKER_USERNAME = credentials('your-registry-username')
   DOCKER_PASSWORD = credentials('your-registry-password')
   ```
3. Update image tags:
   ```groovy
   -t ${DOCKER_REGISTRY}/${service.name}:${DOCKER_TAG}
   ```

### Customize Maven Docker Image
To use a different Maven image version:

```groovy
MAVEN_IMAGE = 'maven:3.9.5-eclipse-temurin-17-alpine'
```

### Add Deployment Stage
To automatically deploy after successful build:

```groovy
stage('Deploy to Kubernetes') {
    steps {
        sh 'kubectl apply -f kubernetes/'
    }
}
```

## Best Practices

1. **Use Docker Agents**: Isolates build environment from Jenkins host
2. **Cache Dependencies**: Mount Maven repo: `-v $HOME/.m2:/root/.m2`
3. **Tag Strategy**: Use build number + latest for traceability
4. **Quality Gates**: Enforce code quality standards
5. **Secure Credentials**: Never hardcode secrets in Jenkinsfile
6. **Clean Up**: Remove old Docker images to save disk space
7. **Parallel Builds**: Consider parallelizing service builds for faster execution

## Additional Resources

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [SonarQube Integration](https://docs.sonarqube.org/latest/analysis/scan/sonarscanner-for-jenkins/)
- [Docker Pipeline Plugin](https://plugins.jenkins.io/docker-workflow/)
- [Spring PetClinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices)
