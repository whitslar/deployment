provider "aws" {
  region = var.aws_region
}

# Data source for latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC (create new or use existing)
resource "aws_vpc" "kerberos_vpc" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-vpc"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "kerberos_igw" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.kerberos_vpc[0].id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-igw"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  )
}

# Public Subnet
resource "aws_subnet" "kerberos_subnet" {
  count = var.create_vpc ? 1 : 0

  vpc_id                  = aws_vpc.kerberos_vpc[0].id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-subnet"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  )
}

# Route Table
resource "aws_route_table" "kerberos_rt" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.kerberos_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kerberos_igw[0].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-rt"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  )
}

# Route Table Association
resource "aws_route_table_association" "kerberos_rta" {
  count = var.create_vpc ? 1 : 0

  subnet_id      = aws_subnet.kerberos_subnet[0].id
  route_table_id = aws_route_table.kerberos_rt[0].id
}

# Local values for VPC and Subnet IDs
locals {
  vpc_id    = var.create_vpc ? aws_vpc.kerberos_vpc[0].id : var.vpc_id
  subnet_id = var.create_vpc ? aws_subnet.kerberos_subnet[0].id : var.subnet_id
}

# Security Group
resource "aws_security_group" "kerberos_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH, HTTP, HTTPS, and Kerberos.io service ports"
  vpc_id      = local.vpc_id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kerberos Vault (NodePort)
  ingress {
    description = "Kerberos Vault"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kerberos Factory (NodePort)
  ingress {
    description = "Kerberos Factory"
    from_port   = 30081
    to_port     = 30081
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kerberos Hub API (NodePort)
  ingress {
    description = "Kerberos Hub API"
    from_port   = 32081
    to_port     = 32081
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kerberos Hub Frontend (NodePort)
  ingress {
    description = "Kerberos Hub Frontend"
    from_port   = 32080
    to_port     = 32080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # VerneMQ MQTT (NodePort)
  ingress {
    description = "VerneMQ MQTT"
    from_port   = 31883
    to_port     = 31883
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # VerneMQ WebSocket (NodePort)
  ingress {
    description = "VerneMQ WebSocket"
    from_port   = 31080
    to_port     = 31080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # TURN Server
  ingress {
    description = "TURN Server"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "TURN Server UDP"
    from_port   = 8443
    to_port     = 8443
    protocol    = "udp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # MinIO Console (NodePort)
  ingress {
    description = "MinIO Console"
    from_port   = 30900
    to_port     = 30900
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # MinIO API (NodePort)
  ingress {
    description = "MinIO API"
    from_port   = 30090
    to_port     = 30090
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-sg"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  )
}

# EBS Volume for storage
resource "aws_ebs_volume" "kerberos_storage" {
  availability_zone = var.availability_zone
  size              = var.storage_size_gb
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-storage"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  )
}

# EC2 Instance
resource "aws_instance" "kerberos_microk8s" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = local.subnet_id

  vpc_security_group_ids = [aws_security_group.kerberos_sg.id]

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    storage_device    = "/dev/nvme1n1"
    storage_path      = var.storage_path
    mongodb_password  = var.mongodb_password
    rabbitmq_username = var.rabbitmq_username
    rabbitmq_password = var.rabbitmq_password
    minio_access_key  = var.minio_access_key
    minio_secret_key  = var.minio_secret_key
    vault_username    = var.vault_username
    vault_password    = var.vault_password
    turn_username     = var.turn_username
    turn_password     = var.turn_password
  })

  user_data_replace_on_change = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-instance"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  )

  depends_on = [aws_ebs_volume.kerberos_storage]
}

# Attach EBS volume
resource "aws_volume_attachment" "kerberos_storage_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.kerberos_storage.id
  instance_id = aws_instance.kerberos_microk8s.id

  # Force detachment on destroy
  force_detach = true
}

# Elastic IP (optional but recommended)
resource "aws_eip" "kerberos_eip" {
  count    = var.use_elastic_ip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.kerberos_microk8s.id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-eip"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  )
}