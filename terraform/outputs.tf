output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = local.subnet_id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.kerberos_microk8s.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = var.use_elastic_ip ? aws_eip.kerberos_eip[0].public_ip : aws_instance.kerberos_microk8s.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.kerberos_microk8s.private_ip
}

output "elastic_ip" {
  description = "Elastic IP address (if enabled)"
  value       = var.use_elastic_ip ? aws_eip.kerberos_eip[0].public_ip : null
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.kerberos_sg.id
}

output "storage_volume_id" {
  description = "ID of the EBS storage volume"
  value       = aws_ebs_volume.kerberos_storage.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${var.use_elastic_ip ? aws_eip.kerberos_eip[0].public_ip : aws_instance.kerberos_microk8s.public_ip}"
}

output "kerberos_vault_url" {
  description = "URL to access Kerberos Vault"
  value       = "http://${var.use_elastic_ip ? aws_eip.kerberos_eip[0].public_ip : aws_instance.kerberos_microk8s.public_ip}:30080"
}

output "kerberos_factory_url" {
  description = "URL to access Kerberos Factory"
  value       = "http://${var.use_elastic_ip ? aws_eip.kerberos_eip[0].public_ip : aws_instance.kerberos_microk8s.public_ip}:30081"
}

output "kerberos_hub_url" {
  description = "URL to access Kerberos Hub"
  value       = "http://${var.use_elastic_ip ? aws_eip.kerberos_eip[0].public_ip : aws_instance.kerberos_microk8s.public_ip}:32080"
}

output "minio_console_url" {
  description = "URL to access MinIO Console"
  value       = "http://${var.use_elastic_ip ? aws_eip.kerberos_eip[0].public_ip : aws_instance.kerberos_microk8s.public_ip}:30900"
}

output "deployment_status_command" {
  description = "Command to check deployment status"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${var.use_elastic_ip ? aws_eip.kerberos_eip[0].public_ip : aws_instance.kerberos_microk8s.public_ip} 'microk8s kubectl get pods -A'"
}