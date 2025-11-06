# Terraform Configuration for Kerberos.io on MicroK8s

This Terraform configuration deploys a complete Kerberos.io video surveillance stack on a single-node EC2 instance running MicroK8s.

## Architecture

The deployment creates:
- **VPC**: New VPC with public subnet (or use existing VPC)
- **Internet Gateway**: For public internet access
- **Route Table**: Configured for internet routing
- **EC2 Instance**: t3.large (2 vCPU, 8GB RAM) running Ubuntu 24.04 LTS
- **EBS Volume**: Dedicated storage volume for recordings and data (default 10GB)
- **Security Group**: Configured with all necessary ports for Kerberos.io services
- **Elastic IP**: Optional static IP address for the instance
- **MicroK8s Cluster**: Single-node Kubernetes cluster with all components

## Components Deployed

- **Kerberos Vault**: Storage and metadata management
- **Kerberos Factory**: Camera management UI
- **Kerberos Hub**: Central monitoring dashboard
- **Kerberos Agent**: Video capture and processing
- **MongoDB**: Database for metadata
- **RabbitMQ**: Message broker for events
- **MinIO**: Object storage for recordings
- **VerneMQ**: MQTT broker for real-time communication
- **Coturn**: TURN server for WebRTC streaming

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with credentials
4. **SSH Key Pair** - See [SSH Key Setup](#ssh-key-setup) below

## SSH Key Setup

You need an SSH key pair to access the EC2 instance. Choose one of these options:

### Option 1: Use Existing SSH Key

If you already have an SSH key in AWS:
```hcl
key_name = "my-existing-key"
```

### Option 2: Create New SSH Key

**Using AWS CLI:**
```bash
aws ec2 create-key-pair \
  --key-name kerberos-microk8s-key \
  --region us-east-2 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/kerberos-microk8s-key.pem

chmod 400 ~/.ssh/kerberos-microk8s-key.pem
```

**Using AWS Console:**
1. Go to EC2 → Key Pairs → Create key pair
2. Name: `kerberos-microk8s-key`
3. Download and save to `~/.ssh/`
4. `chmod 400 ~/.ssh/kerberos-microk8s-key.pem`

**Import Your Own Key:**
```bash
aws ec2 import-key-pair \
  --key-name my-ssh-key \
  --region us-east-2 \
  --public-key-material fileb://~/.ssh/id_rsa.pub
```

## Quick Start

### 1. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- SSH key name
- Environment and cost center tags
- **IMPORTANT**: Change all default passwords!
- **Network**: By default, a new VPC will be created. To use an existing VPC, set `create_vpc = false` and provide VPC/Subnet IDs

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

The deployment takes approximately 20-25 minutes.

### 5. Access Your Deployment

After deployment completes, Terraform will output:
- Instance public IP
- Service URLs
- SSH command

You can also SSH to the instance and view the access information:

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>
cat ACCESS_INFO.txt
```

## Service Access

Once deployed, access the services at:

- **Kerberos Vault**: `http://<instance-ip>:30080`
- **Kerberos Factory**: `http://<instance-ip>:30081`
- **Kerberos Hub**: `http://<instance-ip>:32080`
- **MinIO Console**: `http://<instance-ip>:30900`

## Configuration

### Instance Type

The default `t3.large` instance provides:
- 2 vCPUs
- 8 GB RAM
- Good for 5-10 cameras

For more cameras, consider:
- `t3.xlarge` (4 vCPU, 16GB) - 10-20 cameras
- `t3.2xlarge` (8 vCPU, 32GB) - 20-40 cameras

### Storage

The default 10GB EBS volume is suitable for testing and development. For production use:
- 100GB - ~7 days of recordings from 5-10 cameras
- 500GB - ~30 days of recordings from 5-10 cameras
- 1TB+ - Long-term storage or more cameras

Adjust `storage_size_gb` in `terraform.tfvars` based on your needs.

### Network Configuration

**Option 1: Create New VPC (Default)**

The configuration will automatically create:
- VPC with CIDR 10.0.0.0/16
- Public subnet with CIDR 10.0.1.0/24
- Internet Gateway
- Route table with internet access

```hcl
create_vpc  = true
vpc_cidr    = "10.0.0.0/16"
subnet_cidr = "10.0.1.0/24"
```

**Option 2: Use Existing VPC**

If you have an existing VPC:

```hcl
create_vpc = false
vpc_id     = "vpc-xxxxx"
subnet_id  = "subnet-xxxxx"
```

### Security

**IMPORTANT**: The default configuration allows access from anywhere (`0.0.0.0/0`).

For production, restrict access:

```hcl
allowed_cidr_blocks     = ["your.office.ip/32"]
allowed_ssh_cidr_blocks = ["your.office.ip/32"]
```

### Tags

All resources are tagged with:
- **Project**: Kerberos.io
- **ManagedBy**: Terraform
- **Environment**: Configurable (default: production)
- **CostCenter**: Configurable (default: security-operations)

Customize these in `terraform.tfvars`:

```hcl
environment = "production"
cost_center = "security-operations"

tags = {
  Project     = "Kerberos.io"
  ManagedBy   = "Terraform"
  Environment = "production"
  CostCenter  = "security-operations"
  Owner       = "your-name"
}
```

## Post-Deployment Configuration

### 1. Configure Vault Storage Provider

1. Access Vault at `http://<instance-ip>:30080`
2. Login with your vault credentials
3. Navigate to **Storage Providers** → **Add Storage Provider**
4. Configure MinIO:
   - Provider name: `minio`
   - Bucket name: `mybucket`
   - Region: `na`
   - Hostname: `myminio-hl.minio-tenant:9000`
   - Access key: (from your tfvars)
   - Secret key: (from your tfvars)

### 2. Configure Vault Integration

1. Navigate to **Integrations** → **Add Integration**
2. Configure RabbitMQ:
   - Integration name: `rabbitmq`
   - Broker: `rabbitmq.rabbitmq:5672`
   - Queue: `data-filtering`
   - Username: (from your tfvars)
   - Password: (from your tfvars)

### 3. Create Vault Account

1. Navigate to **Accounts** → **Add Account**
2. Configure:
   - Account name: `myaccount`
   - Main provider: `minio`
   - Day limit: `30`
   - Integration: `rabbitmq`
   - Generate access/secret keys (save these!)

### 4. Add Cameras

Use Kerberos Factory at `http://<instance-ip>:30081` to add cameras through the UI.

## Monitoring

### Check Deployment Status

```bash
# SSH to instance
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>

# Check all pods
microk8s kubectl get pods -A

# View logs
microk8s kubectl logs -f <pod-name> -n <namespace>
```

### View Deployment Logs

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>
sudo tail -f /var/log/user-data.log
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
microk8s kubectl get pods -A

# Describe problematic pod
microk8s kubectl describe pod <pod-name> -n <namespace>

# Check events
microk8s kubectl get events -A --sort-by='.lastTimestamp'
```

### Storage Issues

```bash
# Check storage mount
df -h /media/storage

# Check PVCs
microk8s kubectl get pvc -A
```

### Network Issues

```bash
# Check security group rules in AWS Console
# Verify instance has public IP
# Check coturn status
sudo systemctl status coturn
```

## Cost Estimation

Approximate monthly costs (us-east-2):
- t3.large instance: ~$60/month
- 10GB EBS gp3: ~$1/month
- Elastic IP: ~$3.60/month (if not attached)
- Data transfer: Variable

**Total**: ~$65/month (excluding data transfer)

For production with 500GB storage: ~$105/month

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**WARNING**: This will delete:
- The EC2 instance
- The EBS volume and all recordings
- The Elastic IP
- The security group

Make sure to backup any important data first!

## Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region | `us-east-2` | No |
| `project_name` | Project name for resources | `kerberos-microk8s` | No |
| `instance_type` | EC2 instance type | `t3.large` | No |
| `key_name` | SSH key pair name | - | Yes |
| `create_vpc` | Create new VPC | `true` | No |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` | No |
| `subnet_cidr` | Subnet CIDR block | `10.0.1.0/24` | No |
| `vpc_id` | Existing VPC ID | `""` | No* |
| `subnet_id` | Existing Subnet ID | `""` | No* |
| `availability_zone` | AZ for EBS volume | - | Yes |
| `storage_size_gb` | EBS volume size | `10` | No |
| `storage_path` | Mount path for storage | `/media/storage` | No |
| `allowed_cidr_blocks` | Allowed IPs for services | `["0.0.0.0/0"]` | No |
| `allowed_ssh_cidr_blocks` | Allowed IPs for SSH | `["0.0.0.0/0"]` | No |
| `use_elastic_ip` | Create Elastic IP | `true` | No |
| `mongodb_password` | MongoDB password | - | Yes |
| `rabbitmq_username` | RabbitMQ username | `yourusername` | No |
| `rabbitmq_password` | RabbitMQ password | - | Yes |
| `minio_access_key` | MinIO access key | `minio` | No |
| `minio_secret_key` | MinIO secret key | `minio123` | No |
| `vault_username` | Vault username | `root` | No |
| `vault_password` | Vault password | - | Yes |
| `turn_username` | TURN server username | `username1` | No |
| `turn_password` | TURN server password | `password1` | No |
| `environment` | Environment name | `production` | No |
| `cost_center` | Cost center for billing | `security-operations` | No |

## Support

For issues specific to:
- **Terraform configuration**: Open an issue in this repository
- **Kerberos.io components**: Visit [Kerberos.io documentation](https://doc.kerberos.io/)
- **MicroK8s**: Visit [MicroK8s documentation](https://microk8s.io/docs)