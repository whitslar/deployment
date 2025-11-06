variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "kerberos-microk8s"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "key_name" {
  description = "Name of the SSH key pair to use for the instance"
  type        = string
}

variable "create_vpc" {
  description = "Whether to create a new VPC or use an existing one"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (only used if create_vpc is true)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet (only used if create_vpc is true)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vpc_id" {
  description = "VPC ID where resources will be created (only used if create_vpc is false)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched (only used if create_vpc is false)"
  type        = string
  default     = ""
}

variable "availability_zone" {
  description = "Availability zone for EBS volume (must match instance AZ)"
  type        = string
}

variable "storage_size_gb" {
  description = "Size of the EBS volume for storage in GB"
  type        = number
  default     = 10
}

variable "storage_path" {
  description = "Path where storage will be mounted on the instance"
  type        = string
  default     = "/media/storage"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Kerberos.io services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "use_elastic_ip" {
  description = "Whether to create and attach an Elastic IP"
  type        = bool
  default     = true
}

variable "mongodb_password" {
  description = "Password for MongoDB root user"
  type        = string
  sensitive   = true
}

variable "rabbitmq_username" {
  description = "Username for RabbitMQ"
  type        = string
  default     = "yourusername"
}

variable "rabbitmq_password" {
  description = "Password for RabbitMQ"
  type        = string
  sensitive   = true
}

variable "minio_access_key" {
  description = "Access key for MinIO"
  type        = string
  default     = "minio"
}

variable "minio_secret_key" {
  description = "Secret key for MinIO"
  type        = string
  sensitive   = true
  default     = "minio123"
}

variable "vault_username" {
  description = "Username for Kerberos Vault"
  type        = string
  default     = "root"
}

variable "vault_password" {
  description = "Password for Kerberos Vault"
  type        = string
  sensitive   = true
}

variable "turn_username" {
  description = "Username for TURN server"
  type        = string
  default     = "username1"
}

variable "turn_password" {
  description = "Password for TURN server"
  type        = string
  sensitive   = true
  default     = "password1"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Kerberos.io"
    ManagedBy   = "Terraform"
    Environment = "production"
    CostCenter  = "security-operations"
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "production"
}

variable "cost_center" {
  description = "Cost center for billing and tracking"
  type        = string
  default     = "security-operations"
}