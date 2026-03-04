# Secure CI/CD Pipeline with ECS

A security-hardened Jenkins pipeline deploying a Node.js application to AWS ECS Fargate with integrated SAST, SCA, container scanning, SBOM generation, and automated rollback.

---

##  Project Screenshots

### Jenkins Pipeline execution

![Jenkins Pipeline - Build & Scan](screenshoots/jenkinsfirststages.png)
![Jenkins Pipeline - Security & Deploy](screenshoots/jenkinlaststages.png)

### SonarQube Code Quality Analysis

![SonarQube Dashboard](screenshoots/sonarqube.png)

### Security Reports & Dashboard

![Snyk Vulnerability Scan](screenshoots/snyk.png)
![Security Artifacts](screenshoots/artifacts.png)

---

##  Table of Contents

0. [Project Screenshots](#-project-screenshots)
1. [Quick Start](#-quick-start)
2. [Prerequisites](#-prerequisites)
3. [All Required Credentials](#-all-required-credentials)
4. [Step-by-Step Setup](#-step-by-step-setup)
5. [Running the Pipeline](#-running-the-pipeline)
6. [Testing the Application](#-testing-the-application)
7. [Security Gate Testing](#-security-gate-testing)
8. [Troubleshooting](#-troubleshooting)
9. [Cleanup](#-cleanup)

---

##  Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/viateur-amalitech/jenkins-pipeline.git
cd jenkins-pipeline

# 2. Configure AWS credentials
aws configure

# 3. Setup Terraform backend
./scripts/setup-backend.sh

# 4. Deploy infrastructure
./scripts/deploy-infrastructure.sh --environment dev --auto-approve

# 5. Configure Jenkins with credentials (see below)
# 6. Run the pipeline
```

---

##  Prerequisites

### Local Machine Requirements

| Tool | Version | Installation |
|------|---------|-------------|
| AWS CLI | v2.x | `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install` |
| Terraform | >= 1.0.0 | `wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip && unzip terraform_1.6.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/` |
| jq | latest | `sudo apt-get install -y jq` |
| Git | latest | `sudo apt-get install -y git` |

### Jenkins Server Requirements

| Tool | Version | Installation Command |
|------|---------|---------------------|
| Docker | latest | `sudo apt-get install -y docker.io && sudo usermod -aG docker jenkins` |
| Node.js | 18.x | `curl -fsSL https://deb.nodesource.com/setup_18.x \| sudo -E bash - && sudo apt-get install -y nodejs` |
| AWS CLI | v2.x | `sudo apt-get install -y awscli` |
| Gitleaks | 8.18.0 | `wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz && tar -xzf gitleaks_8.18.0_linux_x64.tar.gz && sudo mv gitleaks /usr/local/bin/` |
| Trivy | latest | See installation script below |
| Syft | latest | `curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \| sudo sh -s -- -b /usr/local/bin` |
| Snyk | latest | `sudo npm install -g snyk` |
| SonarScanner | 5.x | See installation script below |

<details>
<summary> Jenkins Agent Setup Script (Click to expand)</summary>

```bash
#!/bin/bash
# Run this script on your Jenkins server/agent

# Update system
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io
sudo usermod -aG docker jenkins
sudo systemctl enable docker
sudo systemctl start docker

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install AWS CLI
sudo apt-get install -y awscli

# Install Gitleaks
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
rm gitleaks_8.18.0_linux_x64.tar.gz

# Install Trivy
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# Install Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin

# Install Snyk
sudo npm install -g snyk

# Install SonarQube Scanner
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
unzip sonar-scanner-cli-5.0.1.3006-linux.zip
sudo mv sonar-scanner-5.0.1.3006-linux /opt/sonar-scanner
sudo ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
rm sonar-scanner-cli-5.0.1.3006-linux.zip

# Restart Jenkins to apply Docker group
sudo systemctl restart jenkins

echo "✅ All tools installed successfully!"
echo "Run these commands to verify:"
echo "  docker --version"
echo "  node --version"
echo "  aws --version"
echo "  gitleaks version"
echo "  trivy --version"
echo "  syft --version"
echo "  snyk --version"
echo "  sonar-scanner --version"
```
</details>

---

##  All Required Credentials

### Overview Table

| Credential | Type | Where to Store | How to Obtain |
|------------|------|----------------|---------------|
| AWS Access Key ID | String | Jenkins, Local | AWS IAM Console |
| AWS Secret Access Key | String | Jenkins, Local | AWS IAM Console |
| SonarQube URL | URL | Jenkins | Your SonarQube server |
| SonarQube Token | Token | Jenkins | SonarQube UI |
| Snyk Token | Token | Jenkins | snyk.io account |

---

### 1️ AWS Credentials

**What it's for:** Deploying infrastructure, pushing to ECR, deploying to ECS

**Where to get it:**
1. Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Click **Users** → **Add User**
3. Username: `jenkins-cicd`
4. Select **Programmatic access**
5. Attach policies:
   - `AmazonECS_FullAccess`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `AmazonVPCFullAccess`
   - `IAMFullAccess`
   - `AmazonS3FullAccess`
   - `AmazonDynamoDBFullAccess`
   - `CloudWatchLogsFullAccess`
   - `ElasticLoadBalancingFullAccess`
6. Click **Create User**
7. **Save the Access Key ID and Secret Access Key**

**Where to put it:**

 **Local Machine** (for Terraform):
```bash
aws configure
# AWS Access Key ID: AKIAXXXXXXXXXXXXXXXX
# AWS Secret Access Key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Default region: eu-north-1
# Default output: json
```

 **Jenkins** (for pipeline):
1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Fill in:
   - **Kind:** Username with password
   - **Scope:** Global
   - **Username:** `AKIAXXXXXXXXXXXXXXXX` (your Access Key ID)
   - **Password:** `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` (your Secret Access Key)
   - **ID:** `aws-credentials`
   - **Description:** AWS credentials for CI/CD

---

### 2️ SonarQube Credentials

**What it's for:** Static Application Security Testing (SAST), code quality analysis

**Option A: SonarCloud (Free - Recommended for testing)**

1. Go to [https://sonarcloud.io](https://sonarcloud.io)
2. Click **Log in** → Sign in with GitHub
3. Click **+** → **Analyze new project**
4. Select your repository
5. Get the token:
   - Click your avatar → **My Account** → **Security**
   - Generate token: `jenkins-pipeline-token`
   - **Copy the token** (shown only once!)
6. Get the organization key from your organization settings

**URL:** `https://sonarcloud.io`
**Token:** `sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

**Option B: Self-hosted SonarQube**

```bash
# Run SonarQube locally with Docker
docker run -d --name sonarqube \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:lts-community

# Wait for startup (takes ~2 minutes)
sleep 120

# Access: http://localhost:9000
# Default login: admin / admin (change on first login)
```

Generate token in SonarQube:
1. Login to SonarQube
2. Go to **Administration** → **Security** → **Users**
3. Click on your user → **Tokens**
4. Generate: `jenkins-token`
5. **Copy the token**

**URL:** `http://your-server:9000`
**Token:** `squ_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

**Where to put it in Jenkins:**

📍 **SonarQube URL:**
1. **Manage Jenkins** → **Credentials** → **Add Credentials**
2. Fill in:
   - **Kind:** Secret text
   - **Scope:** Global
   - **Secret:** `https://sonarcloud.io` (or your server URL)
   - **ID:** `sonarqube-url`
   - **Description:** SonarQube Server URL

📍 **SonarQube Token:**
1. **Manage Jenkins** → **Credentials** → **Add Credentials**
2. Fill in:
   - **Kind:** Secret text
   - **Scope:** Global
   - **Secret:** `sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - **ID:** `sonarqube-token`
   - **Description:** SonarQube Authentication Token

 **Configure SonarQube Server in Jenkins:**
1. **Manage Jenkins** → **Configure System**
2. Scroll to **SonarQube servers**
3. Check **Environment variables**
4. Click **Add SonarQube**
5. Fill in:
   - **Name:** `SonarQube`
   - **Server URL:** `https://sonarcloud.io`
   - **Server authentication token:** Select `sonarqube-token`

---

### 3️ Snyk Credentials

**What it's for:** Software Composition Analysis (SCA), dependency vulnerability scanning

**How to get it:**
1. Go to [https://snyk.io](https://snyk.io)
2. Click **Sign up** → Sign up with GitHub
3. After login, click your name (bottom left) → **Account Settings**
4. Scroll to **API Token**
5. Click **click to show** or **Regenerate**
6. **Copy the token**

**Token format:** `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

**Where to put it in Jenkins:**
1. **Manage Jenkins** → **Credentials** → **Add Credentials**
2. Fill in:
   - **Kind:** Secret text
   - **Scope:** Global
   - **Secret:** `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - **ID:** `snyk-token`
   - **Description:** Snyk API Token

---

###  Jenkins Credentials Summary

After setup, you should have these 4 credentials in Jenkins:

| ID | Kind | Description |
|----|------|-------------|
| `aws-credentials` | Username with password | AWS Access Key (username) + Secret Key (password) |
| `sonarqube-url` | Secret text | SonarQube server URL |
| `sonarqube-token` | Secret text | SonarQube authentication token |
| `snyk-token` | Secret text | Snyk API token |

**Verify in Jenkins:**
1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. You should see all 4 credentials listed

---

##  Step-by-Step Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/viateur-amalitech/jenkins-pipeline.git
cd jenkins-pipeline
```

### Step 2: Configure AWS CLI

```bash
aws configure
```

Enter:
- **AWS Access Key ID:** Your access key
- **AWS Secret Access Key:** Your secret key
- **Default region:** `eu-north-1`
- **Default output format:** `json`

Verify:
```bash
aws sts get-caller-identity
# Should show your account ID
```

### Step 3: Setup Terraform Backend

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Setup backend (creates S3 bucket + DynamoDB table)
./scripts/setup-backend.sh --region eu-north-1 --project secure-webapp
```

Expected output:
```
============================================
Terraform Backend Setup
============================================

AWS Account ID: 123456789012
AWS Region:     eu-north-1
Project Name:   secure-webapp
S3 Bucket:      secure-webapp-tfstate-123456789012
DynamoDB Table: secure-webapp-tf-locks

Creating S3 bucket for Terraform state...
✓ S3 bucket created
✓ Versioning enabled
✓ Encryption enabled
✓ Public access blocked
Creating DynamoDB table for state locking...
✓ DynamoDB table created

============================================
Backend setup complete!
============================================
```

### Step 4: Deploy Infrastructure

```bash
# Deploy dev environment
./scripts/deploy-infrastructure.sh --environment dev --auto-approve
```

This creates:
- VPC with public/private subnets
- ECR repository
- ECS Cluster (Fargate)
- Application Load Balancer
- IAM roles
- CloudWatch log groups

**Note the outputs** (you'll need these):
```
ecr_repository_url = "123456789012.dkr.ecr.eu-north-1.amazonaws.com/secure-webapp"
ecs_cluster_name = "secure-webapp-dev-cluster"
ecs_service_name = "secure-webapp-dev-service"
alb_dns_name = "secure-webapp-dev-alb-123456789.eu-north-1.elb.amazonaws.com"
```

### Step 5: Install Jenkins Plugins

In Jenkins UI:
1. Go to **Manage Jenkins** → **Plugins** → **Available plugins**
2. Search and install:
   - ✅ Docker Pipeline
   - ✅ Pipeline: AWS Steps
   - ✅ SonarQube Scanner
   - ✅ Credentials Binding
   - ✅ Pipeline Utility Steps
3. Click **Install** and restart Jenkins

### Step 6: Add Credentials to Jenkins

Follow the [All Required Credentials](#-all-required-credentials) section above to add:
- `aws-credentials`
- `sonarqube-url`
- `sonarqube-token`
- `snyk-token`

### Step 7: Create Jenkins Pipeline Job

1. Click **New Item**
2. Enter name: `secure-webapp-pipeline`
3. Select **Pipeline** → Click **OK**
4. Configure:
   - **General:**
     - ✅ Do not allow concurrent builds
   - **Pipeline:**
     - Definition: **Pipeline script from SCM**
     - SCM: **Git**
     - Repository URL: `https://github.com/viateur-amalitech/jenkins-pipeline.git`
     - Branch: `*/main`
     - Script Path: `Jenkinsfile`
5. Click **Save**

---

##  Running the Pipeline

### First Run (Setup Infrastructure via Pipeline)

1. Go to your pipeline job
2. Click **Build with Parameters**
3. Set parameters:
   - `AWS_REGION`: `eu-north-1`
   - `PROJECT_NAME`: `secure-webapp`
   - `ENVIRONMENT`: `dev`
   - `SETUP_BACKEND`: ✅ (check this)
   - `DEPLOY_INFRASTRUCTURE`: ✅ (check this)
4. Click **Build**

### Subsequent Runs (Deploy Application Only)

1. Click **Build with Parameters**
2. Set parameters:
   - `AWS_REGION`: `eu-north-1`
   - `PROJECT_NAME`: `secure-webapp`
   - `ENVIRONMENT`: `dev`
   - `SETUP_BACKEND`: ❌ (uncheck)
   - `DEPLOY_INFRASTRUCTURE`: ❌ (uncheck)
3. Click **Build**

### Pipeline Stages

| Stage | Description | Duration |
|-------|-------------|----------|
| Validate Parameters | Auto-detects AWS Account ID, generates names | ~5s |
| Initialize | Creates report directories | ~2s |
| Setup Backend | Creates S3 + DynamoDB (if enabled) | ~30s |
| Deploy Infrastructure | Runs Terraform (if enabled) | ~3-5min |
| Checkout | Clones repository | ~10s |
| Install Dependencies | `npm ci` | ~30s |
| Security Scans | Gitleaks, SonarQube, Snyk (parallel) | ~2min |
| Unit Tests | `npm test` | ~30s |
| Quality Gate | Waits for SonarQube analysis | ~1min |
| Security Gate | Fails if vulnerabilities found | ~5s |
| Docker Build | Builds container image | ~1min |
| Container Security | Trivy scan + SBOM generation (parallel) | ~2min |
| Container Gate | Fails if critical vulnerabilities | ~5s |
| Push to ECR | Pushes image to registry | ~1min |
| Deploy to ECS | Updates ECS service | ~30s |
| Wait for Deployment | Waits for healthy deployment | ~5min |
| Cleanup | Removes local images | ~10s |

**Total Time:** ~15-20 minutes (first run with infrastructure)

---

##  Testing the Application

### 1. Get the Application URL

```bash
# From Terraform output
./scripts/deploy-infrastructure.sh --environment dev --action output

# Or via AWS CLI
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `secure-webapp`)].DNSName' \
  --output text
```

### 2. Test the Endpoints

```bash
# Set the ALB URL
export ALB_URL="secure-webapp-dev-alb-123456789.eu-north-1.elb.amazonaws.com"

# Test root endpoint
curl http://${ALB_URL}/
# Expected: {"message":"Hello from secure-webapp!","version":"v1-abc1234","environment":"production"}

# Test health check
curl http://${ALB_URL}/health
# Expected: {"status":"healthy"}

# Test users endpoint (if MongoDB is configured)
curl http://${ALB_URL}/users
# Expected: {"users":[]} or list of users
```

### 3. Check AWS Console

- **ECS:** Check service running with desired count
- **CloudWatch:** Check logs at `/ecs/secure-webapp-dev-service`
- **ECR:** Verify images pushed with correct tags

---

##  Security Gate Testing

### Test 1: Vulnerable Dependency (Snyk)

```bash
# Add vulnerable package
echo '{"dependencies":{"lodash":"4.17.15"}}' > test-package.json

# Edit package.json to include vulnerable lodash
# Then commit and push
```

**Expected:** Pipeline fails at **Security Gate** with "High/Critical vulnerabilities found"

### Test 2: Secret Detection (Gitleaks)

```bash
# Add a secret to any file (DON'T COMMIT TO REAL REPO!)
echo 'const AWS_KEY = "AKIAIOSFODNN7EXAMPLE";' >> temp-test.js

# Commit and push
```

**Expected:** Pipeline fails at **Security Gate** with "Secrets detected in code"

### Test 3: Container Vulnerabilities (Trivy)

```bash
# Use a vulnerable base image in Dockerfile
# Change: FROM node:18-alpine
# To:     FROM node:14-alpine (older, has vulnerabilities)
```

**Expected:** Pipeline fails at **Container Gate** with "Critical/High vulnerabilities in image"

### Test 4: Skip Security Gates (Emergency)

Run pipeline with:
- `SKIP_SECURITY_GATES`: ✅ (checked)

**Expected:** Pipeline continues despite vulnerabilities (use with caution!)

---

## 🔧Troubleshooting

### Issue: "AWS Account ID not detected"

**Solution:**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# If error, reconfigure
aws configure
```

### Issue: "Backend bucket not found"

**Solution:**
```bash
# Run setup script
./scripts/setup-backend.sh --region eu-north-1 --project secure-webapp

# Verify bucket exists
aws s3 ls | grep tfstate
```

### Issue: "ECR authentication failed"

**Solution:**
```bash
# Login to ECR manually
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.eu-north-1.amazonaws.com
```

### Issue: "ECS service not stable"

**Solution:**
```bash
# Check service events
aws ecs describe-services \
  --cluster secure-webapp-dev-cluster \
  --services secure-webapp-dev-service \
  --query 'services[0].events[0:5]'

# Check task logs
aws logs get-log-events \
  --log-group-name /ecs/secure-webapp-dev-service \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name /ecs/secure-webapp-dev-service \
    --order-by LastEventTime --descending \
    --query 'logStreams[0].logStreamName' --output text) \
  --limit 50
```

### Issue: "SonarQube connection failed"

**Solution:**
1. Verify URL is correct in Jenkins credentials
2. Verify token is valid
3. For SonarCloud, ensure organization exists
4. Check network connectivity to SonarQube server

### Issue: "Snyk authentication failed"

**Solution:**
1. Regenerate token at [snyk.io](https://snyk.io)
2. Update `snyk-token` credential in Jenkins
3. Verify token works:
```bash
SNYK_TOKEN=your-token snyk auth
```

---

##  Cleanup

### Step 1: Destroy Application Infrastructure

```bash
# Destroy dev environment
./scripts/deploy-infrastructure.sh --environment dev --action destroy --auto-approve

# Destroy prod environment (if created)
./scripts/deploy-infrastructure.sh --environment prod --action destroy --auto-approve
```

### Step 2: Destroy Terraform Backend

```bash
# This permanently deletes state files!
./scripts/destroy-backend.sh --force
```

### Step 3: Clean Up Jenkins

1. Delete the pipeline job
2. Remove credentials (optional)

### Step 4: Clean Up Docker (Local)

```bash
# Remove images
docker rmi $(docker images | grep secure-webapp | awk '{print $3}')

# Prune system
docker system prune -af
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              CI/CD PIPELINE ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌──────────┐     ┌──────────┐     ┌─────────────────────────────────────────┐     │
│   │  GitHub  │────►│ Jenkins  │────►│           Security Scans                │     │
│   │   Repo   │     │ Pipeline │     │  ┌─────────┬───────────┬─────────┐      │     │
│   └──────────┘     └──────────┘     │  │Gitleaks │ SonarQube │  Snyk   │      │     │
│                                      │  │(Secrets)│  (SAST)   │  (SCA)  │      │     │
│                                      │  └────┬────┴─────┬─────┴────┬────┘      │     │
│                                      └───────┼──────────┼──────────┼───────────┘     │
│                                              │          │          │                 │
│                                              ▼          ▼          ▼                 │
│                                      ┌─────────────────────────────────┐             │
│                                      │      SECURITY GATE (PASS/FAIL)  │             │
│                                      └──────────────┬──────────────────┘             │
│                                                     │                                │
│                                                     ▼                                │
│   ┌────────────────────────────────────────────────────────────────────────────┐    │
│   │                           Container Build & Scan                            │    │
│   │  ┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐   │    │
│   │  │   Docker   │────►│   Trivy    │────►│    Syft    │────►│ Container  │   │    │
│   │  │   Build    │     │   Scan     │     │   (SBOM)   │     │   Gate     │   │    │
│   │  └────────────┘     └────────────┘     └────────────┘     └──────┬─────┘   │    │
│   └──────────────────────────────────────────────────────────────────┼─────────┘    │
│                                                                       │              │
│                                                                       ▼              │
│   ┌────────────────────────────────────────────────────────────────────────────┐    │
│   │                              AWS Deployment                                 │    │
│   │  ┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐   │    │
│   │  │    ECR     │────►│    ECS     │────►│    ALB     │────►│ CloudWatch │   │    │
│   │  │   Push     │     │  Fargate   │     │            │     │    Logs    │   │    │
│   │  └────────────┘     └────────────┘     └────────────┘     └────────────┘   │    │
│   └────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

##  Quick Reference

### Jenkins Credentials

| ID | Kind | Value |
|----|------|-------|
| `aws-credentials` | Username/Password | AWS Access Key / Secret Key |
| `sonarqube-url` | Secret text | `https://sonarcloud.io` or your server |
| `sonarqube-token` | Secret text | SonarQube API token |
| `snyk-token` | Secret text | Snyk API token |

### Pipeline Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `AWS_REGION` | `eu-north-1` | AWS region |
| `PROJECT_NAME` | `secure-webapp` | Project name |
| `ENVIRONMENT` | `dev` | dev or prod |
| `SETUP_BACKEND` | `false` | Create Terraform backend |
| `DEPLOY_INFRASTRUCTURE` | `false` | Deploy Terraform |
| `SKIP_SECURITY_GATES` | `false` | Skip security checks |

### Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/setup-backend.sh` | Create S3 + DynamoDB for Terraform |
| `./scripts/deploy-infrastructure.sh` | Deploy Terraform infrastructure |
| `./scripts/get-backend-config.sh` | Get backend configuration values |
| `./scripts/destroy-backend.sh` | Destroy backend resources |

---

## 📞 Support

For issues:
1. Check [Troubleshooting](#-troubleshooting) section
2. Check Jenkins build logs
3. Check AWS CloudWatch logs
4. Open an issue on GitHub
