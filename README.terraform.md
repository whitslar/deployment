# Terraform Deployment for Kerberos.io on AWS EC2 with MicroK8s

This guide provides a complete Infrastructure-as-Code (IaC) solution for deploying the Kerberos.io video surveillance stack on AWS using Terraform.

## Overview

This Terraform configuration automates the deployment of a production-ready Kerberos.io installation on a single-node MicroK8s cluster running on AWS EC2. The deployment includes all necessary components for a complete video surveillance solution.

## What Gets Deployed

### Infrastructure
- **VPC**: New VPC with public subnet (or use existing VPC)
- **Internet Gateway**: For public internet access
- **Route Table**: Configured for internet routing
- **EC2 Instance**: Ubuntu 24.04 LTS on t3.large (configurable)
- **EBS Volume**: Dedicated 10GB storage volume (configurable)
- **Security Group**: Pre-configured with all required ports
- **Elastic IP**: Optional static IP address
- **Automated Setup**: Complete installation via user-data script

### Kerberos.io Stack
- **Kerberos Vault**: Recording storage and metadata management
- **Kerberos Factory**: Camera management interface
- **Kerberos Hub**: Central monitoring dashboard
- **Kerberos Agent**: Video capture and processing
- **MongoDB**: Metadata database
- **RabbitMQ**: Event message broker
- **MinIO**: Object storage for recordings
- **VerneMQ**: MQTT broker
- **Coturn**: TURN server for WebRTC

## Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate IAM permissions
2. **Terraform** >= 1.0 installed ([Download](https://www.terraform.io/downloads))
3. **AWS CLI** configured with credentials ([Setup Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html))
4. **SSH Key Pair** - See [SSH Key Setup](#ssh-key-setup) below

## SSH Key Setup

You have two options for SSH key management:

### Option 1: Use Existing SSH Key (Recommended)

If you already have an SSH key pair in AWS:

1. Find your key name in AWS Console → EC2 → Key Pairs
2. Use that key name in `terraform.tfvars`:
   ```hcl
   key_name = "my-existing-key"
   ```

### Option 2: Create New SSH Key

**Using AWS CLI:**

```bash
# Create new key pair in us-east-2
aws ec2 create-key-pair \
  --key-name kerberos-microk8s-key \
  --region us-east-2 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/kerberos-microk8s-key.pem

# Set proper permissions
chmod 400 ~/.ssh/kerberos-microk8s-key.pem
```

Then use in `terraform.tfvars`:
```hcl
key_name = "kerberos-microk8s-key"
```

**Using AWS Console:**

1. Go to AWS Console → EC2 → Key Pairs
2. Click "Create key pair"
3. Name: `kerberos-microk8s-key`
4. Key pair type: RSA
5. Private key format: .pem
6. Click "Create key pair"
7. Save the downloaded .pem file to `~/.ssh/`
8. Set permissions: `chmod 400 ~/.ssh/kerberos-microk8s-key.pem`

**Using your own SSH key:**

If you want to use your existing local SSH key:

```bash
# Import your public key to AWS
aws ec2 import-key-pair \
  --key-name my-ssh-key \
  --region us-east-2 \
  --public-key-material fileb://~/.ssh/id_rsa.pub
```

## Quick Start

### Step 1: Navigate to Terraform Directory

```bash
cd terraform
```

### Step 2: Configure Your Deployment

Copy the example configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:

```hcl
# Required: AWS Configuration
aws_region        = "us-east-2"
availability_zone = "us-east-2a"
key_name          = "your-key-name"  # Your SSH key name

# Network: Create new VPC (default) or use existing
create_vpc  = true                   # Set to false to use existing VPC
vpc_cidr    = "10.0.0.0/16"         # Only if create_vpc = true
subnet_cidr = "10.0.1.0/24"         # Only if create_vpc = true

# Required: Security (CHANGE ALL PASSWORDS!)
mongodb_password  = "your-secure-mongodb-password"
rabbitmq_password = "your-secure-rabbitmq-password"
vault_password    = "your-secure-vault-password"
minio_secret_key  = "your-secure-minio-secret"
turn_password     = "your-secure-turn-password"

# Optional: Customize as needed
instance_type   = "t3.large"
storage_size_gb = 10
environment     = "production"
cost_center     = "security-operations"
```

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Review the Deployment Plan

```bash
terraform plan
```

Review the resources that will be created.

### Step 5: Deploy

```bash
terraform apply
```

Type `yes` when prompted. The deployment takes approximately 20-25 minutes.

### Step 6: Access Your System

After deployment, Terraform outputs the access information:

```bash
# View outputs
terraform output

# Get specific output
terraform output instance_public_ip
terraform output kerberos_vault_url
```

SSH to your instance:

```bash
# Use the SSH command from outputs
terraform output -raw ssh_command | bash

# Or manually
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>

# View access information
cat ACCESS_INFO.txt
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS us-east-2                             │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         VPC (kerberos-microk8s-vpc)                │    │
│  │         CIDR: 10.0.0.0/16                          │    │
│  │                                                     │    │
│  │  ┌──────────────────────────────────────────┐     │    │
│  │  │   Internet Gateway (kerberos-microk8s-igw)    │    │
│  │  └──────────────────────────────────────────┘     │    │
│  │                      │                             │    │
│  │  ┌──────────────────▼──────────────────────┐     │    │
│  │  │   Route Table (kerberos-microk8s-rt)    │     │    │
│  │  │   Route: 0.0.0.0/0 → IGW                │     │    │
│  │  └──────────────────────────────────────────┘     │    │
│  │                      │                             │    │
│  │  ┌──────────────────▼──────────────────────┐     │    │
│  │  │   Public Subnet (kerberos-microk8s-subnet)   │    │
│  │  │   CIDR: 10.0.1.0/24                      │     │    │
│  │  │                                          │     │    │
│  │  │  ┌──────────────────────────────────┐  │     │    │
│  │  │  │ Security Group (kerberos-microk8s-sg)    │    │
│  │  │  │  - SSH (22)                      │  │     │    │
│  │  │  │  - HTTP/HTTPS (80/443)           │  │     │    │
│  │  │  │  - Kerberos Services (30080-32081)  │    │    │
│  │  │  │  - TURN Server (8443)            │  │     │    │
│  │  │  └──────────────────────────────────┘  │     │    │
│  │  │                  │                      │     │    │
│  │  │  ┌──────────────▼──────────────────┐  │     │    │
│  │  │  │  EC2 (kerberos-microk8s-instance)  │    │    │
│  │  │  │  t3.large - Ubuntu 24.04 LTS     │  │     │    │
│  │  │                                          │     │    │
│  │  │  ┌────────────────────────────────┐    │     │    │
│  │  │  │      MicroK8s Cluster          │    │     │    │
│  │  │  │                                 │    │     │    │
│  │  │  │  ┌──────────────────────────┐  │    │     │    │
│  │  │  │  │  Kerberos.io Stack       │  │    │     │    │
│  │  │  │  │  - Vault                 │  │    │     │    │
│  │  │  │  │  - Factory               │  │    │     │    │
│  │  │  │  │  - Hub                   │  │    │     │    │
│  │  │  │  │  - Agent                 │  │    │     │    │
│  │  │  │  └──────────────────────────┘  │    │     │    │
│  │  │  │                                 │    │     │    │
│  │  │  │  ┌──────────────────────────┐  │    │     │    │
│  │  │  │  │  Dependencies            │  │    │     │    │
│  │  │  │  │  - MongoDB               │  │    │     │    │
│  │  │  │  │  - RabbitMQ              │  │    │     │    │
│  │  │  │  │  - MinIO                 │  │    │     │    │
│  │  │  │  │  - VerneMQ               │  │    │     │    │
│  │  │  │  └──────────────────────────┘  │    │     │    │
│  │  │  └────────────────────────────────┘    │     │    │
│  │  │                                          │     │    │
│  │  │  ┌────────────────────────────────┐    │     │    │
│  │  │  │      Coturn (TURN Server)      │    │     │    │
│  │  │  └────────────────────────────────┘    │     │    │
│  │  └──────────────────────────────────────────┘     │    │
│  │                      │                             │    │
│  │  ┌──────────────────▼──────────────────────┐     │    │
│  │  │  EBS Volume (kerberos-microk8s-storage) │     │    │
│  │  │    10GB gp3 (configurable)              │     │    │
│  │  │    Mounted at /media/storage            │     │    │
│  │  │    - Recordings                         │     │    │
│  │  │    - Database data                      │     │    │
│  │  │    - Persistent volumes                 │     │    │
│  │  └──────────────────────────────────────────┘     │    │
│  │                                                     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │   Elastic IP (kerberos-microk8s-eip, Optional)     │    │
│  │              Static Public IP                       │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘

All resources tagged with:
- Name: kerberos-microk8s-*
- Environment: production (configurable)
- CostCenter: security-operations (configurable)
```

## Service Endpoints

After deployment, access services at:

| Service | Port | URL |
|---------|------|-----|
| Kerberos Vault | 30080 | `http://<ip>:30080` |
| Kerberos Factory | 30081 | `http://<ip>:30081` |
| Kerberos Hub | 32080 | `http://<ip>:32080` |
| Hub API | 32081 | `http://<ip>:32081` |
| MinIO Console | 30900 | `http://<ip>:30900` |
| MinIO API | 30090 | `http://<ip>:30090` |
| VerneMQ MQTT | 31883 | `tcp://<ip>:31883` |
| VerneMQ WebSocket | 31080 | `ws://<ip>:31080` |
| TURN Server | 8443 | `turn:<ip>:8443` |

## Resource Naming Convention

All AWS resources are named with the `kerberos-microk8s` prefix:

- **VPC**: `kerberos-microk8s-vpc`
- **Internet Gateway**: `kerberos-microk8s-igw`
- **Subnet**: `kerberos-microk8s-subnet`
- **Route Table**: `kerberos-microk8s-rt`
- **Security Group**: `kerberos-microk8s-sg`
- **EC2 Instance**: `kerberos-microk8s-instance`
- **EBS Volume**: `kerberos-microk8s-storage`
- **Elastic IP**: `kerberos-microk8s-eip`

This makes it easy to identify and manage resources in the AWS Console. All resources are also tagged with Environment and CostCenter for cost tracking.

## Post-Deployment Configuration

### 1. Configure Kerberos Vault

Access Vault at `http://<instance-ip>:30080` and login with your credentials.

#### Add Storage Provider (MinIO)

1. Navigate to **Storage Providers** → **Add Storage Provider**
2. Fill in the details:
   ```
   Provider name: minio
   Bucket name: mybucket
   Region: na
   Hostname: myminio-hl.minio-tenant:9000
   Access key: <from your tfvars>
   Secret key: <from your tfvars>
   ```
3. Click **Verify** then **Add Storage Provider**

#### Add Integration (RabbitMQ)

1. Navigate to **Integrations** → **Add Integration**
2. Fill in the details:
   ```
   Integration name: rabbitmq
   Broker: rabbitmq.rabbitmq:5672
   Exchange: (leave empty)
   Queue: data-filtering
   Username: <from your tfvars>
   Password: <from your tfvars>
   ```
3. Click **Verify** then **Add Integration**

#### Create Account

1. Navigate to **Accounts** → **Add Account**
2. Fill in the details:
   ```
   Account name: myaccount
   Main provider: minio
   Day limit: 30
   Integration: rabbitmq
   Directory: *
   ```
3. Generate or enter access/secret keys
4. **Save these keys** - you'll need them for agents!

### 2. Add Cameras via Factory

Access Factory at `http://<instance-ip>:30081`:

1. Login with your credentials
2. Click **Add Camera**
3. Enter camera details (RTSP URL, name, etc.)
4. Use the account keys from Vault
5. Deploy the agent

### 3. Monitor via Hub

Access Hub at `http://<instance-ip>:32080`:

1. Login with your credentials
2. View live streams
3. Search recordings
4. Configure alerts

## Configuration Options

### Instance Sizing

Choose instance type based on camera count:

| Instance Type | vCPU | RAM | Cameras | Monthly Cost* |
|--------------|------|-----|---------|---------------|
| t3.large | 2 | 8GB | 5-10 | ~$60 |
| t3.xlarge | 4 | 16GB | 10-20 | ~$120 |
| t3.2xlarge | 8 | 32GB | 20-40 | ~$240 |
| c5.2xlarge | 8 | 16GB | 30-50 | ~$245 |

*Approximate costs in us-east-2

### Storage Sizing

Calculate storage needs:

```
Storage (GB) = Cameras × Days × Hours × Bitrate (Mbps) × 3600 / 8 / 1024
```

Example for 10 cameras, 30 days, 2 Mbps:
```
10 × 30 × 24 × 2 × 3600 / 8 / 1024 ≈ 777 GB
```

Add 20% buffer: ~930 GB recommended

**Default Configuration**: 10GB (suitable for testing/development)

### Network Configuration

**Option 1: Create New VPC (Default & Recommended)**

The configuration will automatically create a complete network infrastructure:
- VPC with CIDR 10.0.0.0/16
- Public subnet with CIDR 10.0.1.0/24 in your specified AZ
- Internet Gateway for public access
- Route table with internet routing
- All resources properly tagged

```hcl
create_vpc  = true
vpc_cidr    = "10.0.0.0/16"
subnet_cidr = "10.0.1.0/24"
```

**Option 2: Use Existing VPC**

If you have an existing VPC with internet access:

```hcl
create_vpc = false
vpc_id     = "vpc-xxxxx"
subnet_id  = "subnet-xxxxx"  # Must be a public subnet with internet access
```

**Note**: When using an existing VPC, ensure:
- The subnet has internet access (via Internet Gateway or NAT Gateway)
- The subnet's route table allows outbound internet traffic
- The subnet is in the same availability zone as specified

### Tagging Strategy

All resources are tagged for cost tracking and organization:

```hcl
# Default tags
tags = {
  Project     = "Kerberos.io"
  ManagedBy   = "Terraform"
  Environment = "production"
  CostCenter  = "security-operations"
}

# Additional resource-specific tags
Name        = "kerberos-microk8s-<resource>"
Environment = var.environment
CostCenter  = var.cost_center
```

Customize in `terraform.tfvars`:

```hcl
environment = "production"  # or "dev", "staging", etc.
cost_center = "security-operations"  # your cost center code
```

### Security Hardening

For production deployments:

1. **Restrict IP Access**:
   ```hcl
   allowed_cidr_blocks     = ["your.office.ip/32"]
   allowed_ssh_cidr_blocks = ["your.admin.ip/32"]
   ```

2. **Use Strong Passwords**: Generate with:
   ```bash
   openssl rand -base64 32
   ```

3. **Enable AWS Security Features**:
   - Enable VPC Flow Logs
   - Use AWS Systems Manager Session Manager
   - Enable CloudWatch monitoring
   - Configure AWS Backup for EBS volumes

4. **SSL/TLS**: Consider adding a reverse proxy with Let's Encrypt

## Monitoring and Maintenance

### Check System Status

```bash
# SSH to instance
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>

# Check all pods
microk8s kubectl get pods -A

# Check specific service
microk8s kubectl get pods -n kerberos-vault

# View logs
microk8s kubectl logs -f <pod-name> -n <namespace>

# Check resource usage
microk8s kubectl top nodes
microk8s kubectl top pods -A
```

### Monitor Deployment Progress

```bash
# View user-data script logs
sudo tail -f /var/log/user-data.log

# Check if deployment completed
cat /var/log/kerberos-deployment-complete.txt
```

### AWS Cost Tracking

Use AWS Cost Explorer to track costs by tags:

```bash
# View costs by cost center
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=CostCenter

# View costs by environment
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment
```

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
microk8s kubectl get pods -A

# Describe pod for details
microk8s kubectl describe pod <pod-name> -n <namespace>

# Check events
microk8s kubectl get events -A --sort-by='.lastTimestamp'

# Check logs
microk8s kubectl logs <pod-name> -n <namespace>
```

#### Storage Issues

```bash
# Check mount
df -h /media/storage

# Check PVCs
microk8s kubectl get pvc -A

# Check storage class
microk8s kubectl get storageclass
```

#### Network Connectivity

```bash
# Test from instance
curl http://localhost:30080

# Check security group in AWS Console
# Verify Elastic IP is attached
# Check coturn status
sudo systemctl status coturn
```

### Getting Help

1. **Check logs**: `/var/log/user-data.log`
2. **View access info**: `cat ~/ACCESS_INFO.txt`
3. **Kerberos.io docs**: https://doc.kerberos.io/
4. **MicroK8s docs**: https://microk8s.io/docs
5. **Community**: https://github.com/kerberos-io/deployment/discussions

## Cost Optimization

### Estimated Monthly Costs (us-east-2)

| Component | Configuration | Monthly Cost |
|-----------|--------------|--------------|
| EC2 t3.large | 2 vCPU, 8GB RAM | ~$60 |
| EBS gp3 | 10GB | ~$1 |
| Elastic IP | Attached | $0 |
| Data Transfer | Variable | ~$5-20 |
| **Total** | **Default Config** | **~$65** |

For production (500GB storage): ~$105/month

### Reduce Costs

1. **Stop During Off-Hours**:
   ```bash
   # Stop instance (data persists)
   aws ec2 stop-instances --instance-ids <instance-id>
   
   # Start instance
   aws ec2 start-instances --instance-ids <instance-id>
   ```

2. **Use Reserved Instances** for long-term deployments (up to 72% savings)

3. **Optimize Storage**:
   - Use lifecycle policies to delete old recordings
   - Compress recordings
   - Use st1 (throughput optimized) for cold storage

## Cleanup

### Destroy Everything

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy
```

**WARNING**: This permanently deletes:
- VPC and all networking components (if created by Terraform)
- EC2 instance (kerberos-microk8s-instance)
- EBS volume (kerberos-microk8s-storage) and ALL recordings
- Elastic IP (kerberos-microk8s-eip)
- Security group (kerberos-microk8s-sg)

**Note**: If you created the VPC with Terraform (`create_vpc = true`), all networking resources will be automatically cleaned up. If you used an existing VPC, only the EC2 instance, EBS volume, security group, and Elastic IP will be deleted.

### Backup Before Destroying

```bash
# Create EBS snapshot
aws ec2 create-snapshot \
  --volume-id $(terraform output -raw storage_volume_id) \
  --description "Kerberos backup before destroy" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=kerberos-microk8s-backup}]'

# Export configurations
microk8s kubectl get all -A -o yaml > backup.yaml
```

## Advanced Configuration

### Custom Domain with SSL

1. **Point domain to Elastic IP**
2. **Install nginx and certbot**
3. **Configure SSL certificates**

See the detailed README in the `terraform/` directory for full instructions.

### Multi-Environment Setup

Create separate tfvars files for each environment:

```bash
# Development
terraform apply -var-file="dev.tfvars"

# Staging
terraform apply -var-file="staging.tfvars"

# Production
terraform apply -var-file="production.tfvars"
```

## FAQ

**Q: Can I use an existing VPC?**
A: Yes, set `create_vpc = false` and provide the VPC ID and Subnet ID in `terraform.tfvars`. Make sure the subnet has internet access.

**Q: Will Terraform create a VPC for me?**
A: Yes! By default (`create_vpc = true`), Terraform will create a complete VPC with all necessary networking components. Everything will be properly tagged and destroyed together when you run `terraform destroy`.

**Q: What happens to the VPC when I destroy the infrastructure?**
A: If Terraform created the VPC (`create_vpc = true`), it will be automatically destroyed along with all other resources. If you used an existing VPC, it will remain untouched.

**Q: How do I change passwords after deployment?**  
A: Update the values in Kubernetes secrets and restart the affected pods.

**Q: Can I deploy in multiple regions?**  
A: Yes, create separate Terraform workspaces or directories for each region.

**Q: What if deployment fails?**  
A: Check `/var/log/user-data.log` on the instance for errors.

**Q: How do I add more cameras?**  
A: Use Kerberos Factory UI or deploy additional agent pods via kubectl.

**Q: Why us-east-2?**  
A: It's a cost-effective region with good availability. You can change it in `terraform.tfvars`.

**Q: Can I change the resource names?**  
A: Yes, modify the `project_name` variable in `terraform.tfvars`.

## Files Structure

```
terraform/
├── main.tf                      # Main infrastructure definition
├── variables.tf                 # Variable declarations
├── outputs.tf                   # Output definitions
├── versions.tf                  # Terraform version constraints
├── user-data.sh                 # EC2 initialization script
├── terraform.tfvars.example     # Example configuration
├── .gitignore                   # Git ignore rules
└── README.md                    # Detailed documentation
```

## License

This Terraform configuration is provided as-is. See the main Kerberos.io repository for licensing information.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Support

- **Documentation**: https://doc.kerberos.io/
- **Issues**: https://github.com/kerberos-io/deployment/issues
- **Discussions**: https://github.com/kerberos-io/deployment/discussions