# AWS Deployment Guide for HackSmart Streamlit Application

This guide provides comprehensive instructions for deploying the HackSmart Digital Twin Dashboard on Amazon Web Services (AWS) using three different deployment methods.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Deployment Methods Overview](#deployment-methods-overview)
3. [Method 1: AWS Elastic Beanstalk (Recommended for Beginners)](#method-1-aws-elastic-beanstalk)
4. [Method 2: AWS ECS with Fargate (Production-Grade)](#method-2-aws-ecs-with-fargate)
5. [Method 3: AWS EC2 (Manual Control)](#method-3-aws-ec2)
6. [Environment Variables](#environment-variables)
7. [Cost Estimates](#cost-estimates)
8. [Monitoring and Logging](#monitoring-and-logging)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before deploying to AWS, ensure you have the following:

### Required Tools
- **AWS Account**: [Sign up here](https://aws.amazon.com/)
- **AWS CLI**: [Installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Docker**: [Install Docker Desktop](https://www.docker.com/products/docker-desktop)
- **Git**: For version control

### AWS CLI Configuration
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter your default output format (json)
```

### Test Docker Installation
```bash
docker --version
docker run hello-world
```

---

## Deployment Methods Overview

| Method | Complexity | Best For | Estimated Cost/Month |
|--------|-----------|----------|---------------------|
| **Elastic Beanstalk** | Low | Quick deployments, beginners | $30-50 |
| **ECS with Fargate** | Medium | Production apps, auto-scaling | $40-80 |
| **EC2** | High | Maximum control, custom config | $25-60 |

---

## Method 1: AWS Elastic Beanstalk

**Best for**: Teams that want AWS to handle infrastructure management automatically.

### Step 1: Install EB CLI
```bash
pip install awsebcli
eb --version
```

### Step 2: Initialize Elastic Beanstalk
```bash
cd /path/to/hacksmart_demo3_aws

# Initialize EB application
eb init -p docker hacksmart-streamlit --region us-east-1

# Select your default region and create a new keypair when prompted
```

### Step 3: Create Environment and Deploy
```bash
# Create environment (this will take 5-10 minutes)
eb create hacksmart-production \
    --instance-type t3.medium \
    --envvars STREAMLIT_SERVER_PORT=8501,STREAMLIT_SERVER_ADDRESS=0.0.0.0

# Check status
eb status

# Open in browser
eb open
```

### Step 4: Subsequent Deployments
```bash
# After making code changes
eb deploy

# View logs
eb logs

# SSH into instance (if needed)
eb ssh
```

### Step 5: Scaling Configuration
```bash
# Enable auto-scaling
eb scale 2  # Run 2 instances minimum

# Configure auto-scaling rules via AWS Console:
# - Min instances: 1
# - Max instances: 4
# - Scale up when CPU > 70%
# - Scale down when CPU < 30%
```

### Step 6: Custom Domain (Optional)
1. Go to AWS Route 53
2. Create a hosted zone for your domain
3. Add CNAME record pointing to your EB environment URL
4. Configure in EB: `eb config` and update `CNAME`

---

## Method 2: AWS ECS with Fargate

**Best for**: Production applications requiring scalability and container orchestration.

### Step 1: Build and Push Docker Image to ECR

#### Create ECR Repository
```bash
# Set variables
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO_NAME=hacksmart-streamlit

# Create ECR repository
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $AWS_REGION
```

#### Build and Push Image
```bash
# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build Docker image
docker build -t $ECR_REPO_NAME .

# Tag image
docker tag $ECR_REPO_NAME:latest \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest

# Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest
```

### Step 2: Create ECS Cluster
```bash
aws ecs create-cluster \
    --cluster-name hacksmart-cluster \
    --region $AWS_REGION
```

### Step 3: Update and Register Task Definition

Edit `ecs-task-definition.json` and replace placeholders:
- `{ACCOUNT_ID}` with your AWS account ID
- `{REGION}` with your AWS region

```bash
# Create CloudWatch log group
aws logs create-log-group \
    --log-group-name /ecs/hacksmart-streamlit \
    --region $AWS_REGION

# Register task definition
aws ecs register-task-definition \
    --cli-input-json file://ecs-task-definition.json \
    --region $AWS_REGION
```

### Step 4: Create Application Load Balancer

```bash
# Create security group for ALB
aws ec2 create-security-group \
    --group-name hacksmart-alb-sg \
    --description "Security group for HackSmart ALB" \
    --vpc-id vpc-xxxxxxxx

# Add inbound rule for HTTP
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxx \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Create ALB (use AWS Console for easier setup)
# Go to EC2 → Load Balancers → Create Load Balancer
# Select Application Load Balancer
# Configure listener on port 80
# Create target group for port 8501
```

### Step 5: Create ECS Service

Update `ecs-service.json` with your subnet and security group IDs, then:

```bash
aws ecs create-service \
    --cluster hacksmart-cluster \
    --cli-input-json file://ecs-service.json \
    --region $AWS_REGION
```

### Step 6: Access Your Application
```bash
# Get ALB DNS name
aws elbv2 describe-load-balancers \
    --names hacksmart-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text
```

Visit the ALB DNS name in your browser.

### Step 7: Auto-Scaling Configuration
```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id service/hacksmart-cluster/hacksmart-streamlit-service \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 1 \
    --max-capacity 4

# Create scaling policy
aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id service/hacksmart-cluster/hacksmart-streamlit-service \
    --policy-name cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

---

## Method 3: AWS EC2

**Best for**: Users who need maximum control over the environment.

### Step 1: Launch EC2 Instance

```bash
# Create security group
aws ec2 create-security-group \
    --group-name hacksmart-ec2-sg \
    --description "Security group for HackSmart EC2"

# Add inbound rules
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxx \
    --protocol tcp \
    --port 22 \
    --cidr YOUR_IP/32  # SSH access

aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxx \
    --protocol tcp \
    --port 8501 \
    --cidr 0.0.0.0/0  # Streamlit access

# Launch instance (Ubuntu 22.04, t3.medium)
aws ec2 run-instances \
    --image-id ami-0c7217cdde317cfec \
    --instance-type t3.medium \
    --key-name your-key-pair \
    --security-group-ids sg-xxxxxxxx \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=hacksmart-streamlit}]'
```

### Step 2: Connect to Instance
```bash
# Get public IP
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=hacksmart-streamlit" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text

# SSH into instance
ssh -i your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

### Step 3: Install Docker on EC2
```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Logout and login again for group changes to take effect
exit
ssh -i your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

### Step 4: Deploy Application
```bash
# Clone your repository or copy files
git clone https://github.com/your-repo/hacksmart_demo3_aws.git
cd hacksmart_demo3_aws

# Build Docker image
docker build -t hacksmart-streamlit .

# Run container
docker run -d \
    --name hacksmart-app \
    -p 8501:8501 \
    --restart unless-stopped \
    hacksmart-streamlit

# Check logs
docker logs -f hacksmart-app
```

### Step 5: Access Application
Visit `http://YOUR_EC2_PUBLIC_IP:8501` in your browser.

### Step 6: Set Up Automatic Restarts
```bash
# Create systemd service for persistence
sudo tee /etc/systemd/system/hacksmart.service > /dev/null <<EOF
[Unit]
Description=HackSmart Streamlit Application
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a hacksmart-app
ExecStop=/usr/bin/docker stop hacksmart-app

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable hacksmart.service
sudo systemctl start hacksmart.service
```

---

## Environment Variables

Set these environment variables based on your deployment method:

### Required Variables
```bash
STREAMLIT_SERVER_PORT=8501
STREAMLIT_SERVER_ADDRESS=0.0.0.0
STREAMLIT_SERVER_HEADLESS=true
STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
```

### Setting Variables by Method

**Elastic Beanstalk:**
```bash
eb setenv CUSTOM_VAR=value
```

**ECS:**
Add to `ecs-task-definition.json` under `environment` array

**EC2:**
```bash
docker run -d -e CUSTOM_VAR=value ...
```

---

## Cost Estimates

### Elastic Beanstalk (t3.medium, 1 instance)
- EC2 Instance: ~$30/month
- Load Balancer: ~$18/month
- **Total: ~$48/month**

### ECS Fargate (1 vCPU, 2GB RAM, 2 tasks)
- Compute: ~$35/month
- Load Balancer: ~$18/month
- Data Transfer: ~$5/month
- **Total: ~$58/month**

### EC2 (t3.medium)
- Instance: ~$30/month
- Storage (30GB): ~$3/month
- Data Transfer: ~$2/month
- **Total: ~$35/month** (without load balancer)

> [!NOTE]
> Costs assume US East region and moderate traffic. Actual costs may vary.

---

## Monitoring and Logging

### CloudWatch Logs

**View Logs:**
```bash
# Elastic Beanstalk
eb logs

# ECS
aws logs tail /ecs/hacksmart-streamlit --follow

# EC2
docker logs -f hacksmart-app
```

### CloudWatch Metrics

Monitor these key metrics:
- CPU Utilization
- Memory Utilization
- Request Count
- Target Response Time

Access via AWS Console: CloudWatch → Metrics

### Set Up Alarms
```bash
aws cloudwatch put-metric-alarm \
    --alarm-name hacksmart-high-cpu \
    --alarm-description "Alert when CPU exceeds 80%" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2
```

---

## Troubleshooting

### Common Issues

#### 1. Application Won't Start

**Symptoms**: Container exits immediately or health checks fail

**Solutions**:
```bash
# Check Docker logs
docker logs hacksmart-app

# Verify all data files are present
docker exec hacksmart-app ls -la

# Test locally first
docker run -p 8501:8501 hacksmart-streamlit
```

#### 2. High Memory Usage

**Symptoms**: Container gets killed, OOM errors

**Solutions**:
- Increase instance size (t3.large instead of t3.medium)
- Optimize data loading in app.py (use caching)
- For ECS, increase memory in task definition to 4GB

#### 3. Slow Performance

**Symptoms**: Long load times, timeouts

**Solutions**:
- Enable auto-scaling
- Use CloudFront CDN for static assets
- Add ElastiCache for data caching
- Optimize database queries if using external DB

#### 4. Connection Issues

**Symptoms**: Can't access application

**Solutions**:
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxxxxx

# Verify port 8501 (or 80 for ALB) is open
# Check health check status
aws elbv2 describe-target-health --target-group-arn arn:aws:...
```

#### 5. Docker Build Fails

**Symptoms**: Error during `docker build`

**Solutions**:
```bash
# Clear Docker cache
docker system prune -a

# Build with no cache
docker build --no-cache -t hacksmart-streamlit .

# Check for large files (>100MB)
du -sh *
```

### Getting Help

- **AWS Support**: Use AWS Support Center (requires support plan)
- **Streamlit Docs**: https://docs.streamlit.io/
- **AWS Forums**: https://repost.aws/
- **Application Logs**: Always check CloudWatch or Docker logs first

---

## Security Best Practices

1. **Use HTTPS**: Configure SSL/TLS certificates with AWS Certificate Manager
2. **Restrict Access**: Use security groups to limit inbound traffic
3. **Secrets Management**: Use AWS Secrets Manager for sensitive data
4. **IAM Roles**: Use IAM roles instead of access keys where possible
5. **Regular Updates**: Keep Docker images and dependencies updated

---

## Next Steps

After successful deployment:

1. **Set up CI/CD**: Automate deployments with GitHub Actions or AWS CodePipeline
2. **Custom Domain**: Configure Route 53 with your domain name
3. **SSL Certificate**: Add HTTPS with AWS Certificate Manager
4. **Backup Strategy**: Set up automated snapshots and backups
5. **Performance Monitoring**: Configure detailed CloudWatch dashboards

---

**Need Help?** Refer to the main [README.md](README.md) for application-specific documentation.

**Version**: 1.0  
**Last Updated**: 2026-02-01  
**Tested on**: AWS (us-east-1, us-west-2)
