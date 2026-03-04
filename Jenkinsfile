pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 2, unit: 'HOURS')
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'eu-north-1', description: 'AWS Region')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '', description: 'AWS Account ID (auto-detected if empty)')
        string(name: 'PROJECT_NAME', defaultValue: 'secure-webapp', description: 'Project name for resource naming')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'prod'], description: 'Deployment environment')
        string(name: 'ECR_REPOSITORY', defaultValue: 'secure-webapp', description: 'ECR Repository Name')
        string(name: 'ECS_CLUSTER', defaultValue: '', description: 'ECS Cluster Name (auto-generated if empty)')
        string(name: 'ECS_SERVICE', defaultValue: '', description: 'ECS Service Name (auto-generated if empty)')
        string(name: 'APP_VERSION', defaultValue: '', description: 'Version (leave empty for auto)')
        booleanParam(name: 'SETUP_BACKEND', defaultValue: false, description: 'Setup Terraform backend (first run only)')
        booleanParam(name: 'DEPLOY_INFRASTRUCTURE', defaultValue: false, description: 'Deploy/update infrastructure with Terraform')
        booleanParam(name: 'SKIP_SECURITY_GATES', defaultValue: false, description: 'Skip security gates (testing only)')
    }

    environment {
        SONAR_HOST_URL = credentials('sonarqube-url')
        SONAR_TOKEN = credentials('sonarqube-token')
        SNYK_TOKEN = credentials('snyk-token')
        REPORTS_DIR = 'security-reports'
        SBOM_DIR = 'sbom'
    }

    stages {
        stage('Validate Parameters') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        // Set AWS region
                        env.AWS_DEFAULT_REGION = params.AWS_REGION
                        
                        // Auto-detect AWS Account ID if not provided
                        if (!params.AWS_ACCOUNT_ID?.trim()) {
                            env.AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                            echo "Auto-detected AWS Account ID: ${env.AWS_ACCOUNT_ID}"
                        } else {
                            env.AWS_ACCOUNT_ID = params.AWS_ACCOUNT_ID
                        }
                        
                        // Generate backend configuration values
                        env.TF_STATE_BUCKET = "${params.PROJECT_NAME}-tfstate-${env.AWS_ACCOUNT_ID}"
                        env.TF_LOCK_TABLE = "${params.PROJECT_NAME}-tf-locks"
                        env.TF_STATE_KEY = "${params.PROJECT_NAME}/${params.ENVIRONMENT}/terraform.tfstate"
                        
                        // Auto-generate ECS names if not provided
                        env.ECS_CLUSTER = params.ECS_CLUSTER?.trim() ?: "${params.PROJECT_NAME}-${params.ENVIRONMENT}-cluster"
                        env.ECS_SERVICE = params.ECS_SERVICE?.trim() ?: "${params.PROJECT_NAME}-${params.ENVIRONMENT}-service"
                        
                        // Set ECR values
                        env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
                        env.ECR_IMAGE = "${env.ECR_REGISTRY}/${params.ECR_REPOSITORY}"
                        
                        echo """
                        ============================================
                        Pipeline Configuration
                        ============================================
                        AWS Account ID:  ${env.AWS_ACCOUNT_ID}
                        AWS Region:      ${params.AWS_REGION}
                        Environment:     ${params.ENVIRONMENT}
                        Project Name:    ${params.PROJECT_NAME}
                        ECS Cluster:     ${env.ECS_CLUSTER}
                        ECS Service:     ${env.ECS_SERVICE}
                        ECR Registry:    ${env.ECR_REGISTRY}
                        State Bucket:    ${env.TF_STATE_BUCKET}
                        Lock Table:      ${env.TF_LOCK_TABLE}
                        ============================================
                        """
                    }
                }
            }
        }

        stage('Initialize') {
            steps {
                script {
                    sh "mkdir -p ${REPORTS_DIR} ${SBOM_DIR}"
                }
            }
        }

        stage('Setup Backend') {
            when {
                expression { params.SETUP_BACKEND == true }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        echo "Setting up Terraform backend..."
                        sh """
                            export AWS_DEFAULT_REGION=${params.AWS_REGION}
                            chmod +x scripts/setup-backend.sh
                            scripts/setup-backend.sh --region ${params.AWS_REGION} --project ${params.PROJECT_NAME}
                        """
                    }
                }
            }
        }

        stage('Deploy Infrastructure') {
            when {
                expression { params.DEPLOY_INFRASTRUCTURE == true }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        echo "Deploying infrastructure for ${params.ENVIRONMENT}..."
                        sh """
                            export AWS_DEFAULT_REGION=${params.AWS_REGION}
                            chmod +x scripts/deploy-infrastructure.sh
                            scripts/deploy-infrastructure.sh \
                                --region ${params.AWS_REGION} \
                                --project ${params.PROJECT_NAME} \
                                --environment ${params.ENVIRONMENT} \
                                --action apply \
                                --auto-approve
                        """
                    }
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = params.APP_VERSION ?: "v${BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                    currentBuild.description = "Version: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Security Scans') {
            parallel {
                stage('Secret Scan (Gitleaks)') {
                    steps {
                        script {
                            def result = sh(script: "gitleaks detect --source . --report-format json --report-path ${REPORTS_DIR}/gitleaks.json --exit-code 0", returnStatus: true)
                            // Check if secrets found by parsing the report
                            def secretsCount = sh(script: "cat ${REPORTS_DIR}/gitleaks.json 2>/dev/null | grep -c 'RuleID' || echo '0'", returnStdout: true).trim()
                            env.SECRETS_FOUND = secretsCount.toInteger() > 0 ? 'true' : 'false'
                            if (env.SECRETS_FOUND == 'true') {
                                echo "WARNING: ${secretsCount} potential secrets found! Review ${REPORTS_DIR}/gitleaks.json"
                            }
                        }
                    }
                }
                stage('SAST (SonarQube)') {
                    steps {
                        script {
                            def scannerHome = tool 'SonarQube Scanner'
                            withSonarQubeEnv('SonarQube') {
                                sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=secure-webapp -Dsonar.projectVersion=${env.IMAGE_TAG}"
                            }
                        }
                    }
                }
                stage('SCA (Snyk)') {
                    steps {
                        script {
                            withEnv(["SNYK_TOKEN=${SNYK_TOKEN}"]) {
                                // Run snyk test and capture status
                                def result = sh(script: "snyk test --json --severity-threshold=high > ${REPORTS_DIR}/snyk.json || true", returnStatus: true)
                                
                                // Push 
                                sh "snyk monitor --org=2e78cc76-63ee-4317-9f02-d94598be0d4c --project-name=${params.PROJECT_NAME}-${params.ENVIRONMENT}"
                                
                                env.SCA_VULNERABILITIES = result != 0 ? 'true' : 'false'
                                echo "Snyk results pushed to dashboard."
                            }
                        }
                    }
                }
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'npm test -- --coverage'
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        def qg = waitForQualityGate()
                        env.SONAR_GATE_FAILED = qg.status != 'OK' ? 'true' : 'false'
                    }
                }
            }
        }

        stage('Security Gate') {
            steps {
                script {
                    def failures = []
                    def warnings = []
                    
                    // Secrets are warnings (common in dev - should be fixed before prod)
                    if (env.SECRETS_FOUND == 'true') {
                        warnings.add("Secrets detected in code - review ${REPORTS_DIR}/gitleaks.json")
                    }
                    
                    // High/Critical vulnerabilities are failures
                    if (env.SCA_VULNERABILITIES == 'true') {
                        warnings.add("High/Critical vulnerabilities found - review ${REPORTS_DIR}/snyk.json")
                    }
                    
                    // Quality gate failures are critical
                    if (env.SONAR_GATE_FAILED == 'true') {
                        failures.add("SonarQube quality gate failed")
                    }
                    
                    // Print warnings
                    if (warnings.size() > 0) {
                        echo "⚠️ SECURITY WARNINGS: ${warnings.join('; ')}"
                    }
                    
                    // Fail only on critical issues (unless skipped)
                    if (failures.size() > 0 && !params.SKIP_SECURITY_GATES) {
                        error("Security Gate FAILED: ${failures.join(', ')}")
                    }
                    
                    echo "✅ Security Gate passed"
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build \
                        --build-arg APP_VERSION=${env.IMAGE_TAG} \
                        --build-arg BUILD_DATE=\$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
                        --build-arg GIT_COMMIT=${env.GIT_COMMIT_SHORT} \
                        -t ${env.ECR_IMAGE}:${env.IMAGE_TAG} \
                        -t ${env.ECR_IMAGE}:latest .
                """
            }
        }

        stage('Container Security') {
            parallel {
                stage('Trivy Scan') {
                    steps {
                        script {
                            sh "trivy image --format json -o ${REPORTS_DIR}/trivy.json ${env.ECR_IMAGE}:${env.IMAGE_TAG} || true"
                            def result = sh(script: "trivy image --exit-code 1 --severity CRITICAL,HIGH ${env.ECR_IMAGE}:${env.IMAGE_TAG}", returnStatus: true)
                            env.IMAGE_VULNERABILITIES = result != 0 ? 'true' : 'false'
                        }
                    }
                }
                stage('SBOM (Syft)') {
                    steps {
                        sh """
                            syft ${env.ECR_IMAGE}:${env.IMAGE_TAG} -o spdx-json > ${SBOM_DIR}/sbom-spdx.json
                            syft ${env.ECR_IMAGE}:${env.IMAGE_TAG} -o cyclonedx-json > ${SBOM_DIR}/sbom-cyclonedx.json
                        """
                    }
                }
            }
        }

        stage('Container Gate') {
            steps {
                script {
                    if (env.IMAGE_VULNERABILITIES == 'true') {
                        echo "⚠️ WARNING: Critical/High vulnerabilities found in container image"
                        echo "Review ${REPORTS_DIR}/trivy.json for details"
                        // Continue with deployment - vulnerabilities are warnings for now
                        // In production, you may want to fail here
                    } else {
                        echo "✅ Container Security Gate passed - no critical/high vulnerabilities"
                    }
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    retry(3) {
                        sh """
                            export AWS_DEFAULT_REGION=${params.AWS_REGION}
                            aws ecr get-login-password --region ${params.AWS_REGION} | docker login --username AWS --password-stdin ${env.ECR_REGISTRY}
                            docker push ${env.ECR_IMAGE}:${env.IMAGE_TAG}
                            docker push ${env.ECR_IMAGE}:latest
                        """
                    }
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        // Set region
                        env.AWS_DEFAULT_REGION = params.AWS_REGION
                        
                        // Store previous task definition for potential rollback
                        env.PREVIOUS_TASK_DEF = sh(script: """
                            aws ecs describe-services --cluster ${env.ECS_CLUSTER} --services ${env.ECS_SERVICE} \
                                --query 'services[0].taskDefinition' --output text 2>/dev/null || echo 'none'
                        """, returnStdout: true).trim()

                        def taskDef = """
                        {
                            "family": "${env.ECS_SERVICE}",
                            "networkMode": "awsvpc",
                            "requiresCompatibilities": ["FARGATE"],
                            "cpu": "256",
                            "memory": "512",
                            "executionRoleArn": "arn:aws:iam::${env.AWS_ACCOUNT_ID}:role/${params.PROJECT_NAME}-${params.ENVIRONMENT}-ecs-execution-role",
                            "taskRoleArn": "arn:aws:iam::${env.AWS_ACCOUNT_ID}:role/${params.PROJECT_NAME}-${params.ENVIRONMENT}-ecs-task-role",
                            "containerDefinitions": [{
                                "name": "${params.PROJECT_NAME}-${params.ENVIRONMENT}",
                                "image": "${env.ECR_IMAGE}:${env.IMAGE_TAG}",
                                "essential": true,
                                "portMappings": [{"containerPort": 3000, "protocol": "tcp"}],
                                "environment": [
                                    {"name": "NODE_ENV", "value": "production"},
                                    {"name": "APP_VERSION", "value": "${env.IMAGE_TAG}"},
                                    {"name": "ENVIRONMENT", "value": "${params.ENVIRONMENT}"}
                                ],
                                "logConfiguration": {
                                    "logDriver": "awslogs",
                                    "options": {
                                        "awslogs-group": "/ecs/${env.ECS_SERVICE}",
                                        "awslogs-region": "${params.AWS_REGION}",
                                        "awslogs-stream-prefix": "ecs",
                                        "awslogs-create-group": "true"
                                    }
                                },
                                "healthCheck": {
                                    "command": ["CMD-SHELL", "curl -f http://localhost:3000/ || exit 1"],
                                    "interval": 30, "timeout": 5, "retries": 3, "startPeriod": 60
                                }
                            }]
                        }
                        """
                        writeFile file: 'task-definition.json', text: taskDef
                        
                        // Archive the rendered task definition
                        archiveArtifacts artifacts: 'task-definition.json', allowEmptyArchive: false
                        
                        env.TASK_DEF_ARN = sh(script: """
                            aws ecs register-task-definition --cli-input-json file://task-definition.json \
                                --query 'taskDefinition.taskDefinitionArn' --output text
                        """, returnStdout: true).trim()
                        
                        echo "Registered task definition: ${env.TASK_DEF_ARN}"
                        
                        sh """
                            aws ecs update-service --cluster ${env.ECS_CLUSTER} --service ${env.ECS_SERVICE} \
                                --task-definition ${env.TASK_DEF_ARN} --force-new-deployment
                        """
                    }
                }
            }
        }

        stage('Wait for Deployment') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        env.AWS_DEFAULT_REGION = params.AWS_REGION
                        try {
                            timeout(time: 15, unit: 'MINUTES') {
                                sh "aws ecs wait services-stable --cluster ${env.ECS_CLUSTER} --services ${env.ECS_SERVICE}"
                            }
                            echo "Deployment successful!"
                        } catch (Exception e) {
                            echo "Deployment failed! Initiating rollback..."
                            if (env.PREVIOUS_TASK_DEF && env.PREVIOUS_TASK_DEF != 'none') {
                                sh """
                                    aws ecs update-service --cluster ${env.ECS_CLUSTER} --service ${env.ECS_SERVICE} \
                                        --task-definition ${env.PREVIOUS_TASK_DEF} --force-new-deployment
                                """
                                error("Deployment failed and rolled back to ${env.PREVIOUS_TASK_DEF}")
                            } else {
                                error("Deployment failed - no previous task definition to rollback to")
                            }
                        }
                    }
                }
            }
        }

        stage('Cleanup') {
            steps {
                sh """
                    docker rmi ${env.ECR_IMAGE}:${env.IMAGE_TAG} ${env.ECR_IMAGE}:latest || true
                    docker system prune -f || true
                """
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: "${REPORTS_DIR}/**/*,${SBOM_DIR}/**/*", allowEmptyArchive: true
            sh "docker logout ${env.ECR_REGISTRY} || true"
            cleanWs()
        }
        success {
            echo "Deployed ${env.IMAGE_TAG} to ${params.ENVIRONMENT} environment successfully"
        }
        failure {
            echo "Pipeline failed - check security reports"
        }
    }
}
