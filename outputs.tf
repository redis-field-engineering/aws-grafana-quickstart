output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = var.vpc_id != "" ? var.vpc_id : aws_vpc.main[0].id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = var.subnet_id != "" ? var.subnet_id : aws_subnet.main[0].id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.main.id
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "http://${aws_instance.main.public_ip}:3000"
}

output "prometheus_url" {
  description = "URL to access Prometheus"
  value       = "http://${aws_instance.main.public_ip}:9090"
}

output "external_prometheus_endpoint" {
  description = "External Prometheus endpoint being scraped"
  value       = var.prometheus_endpoint
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/redis-observability ubuntu@${aws_instance.main.public_ip}"
}

output "deployment_summary" {
  description = "Summary of the deployment"
  sensitive   = true
  value = <<EOF

🎉 Redis Observability Stack Deployed Successfully!

📊 Services Available:
  • Grafana: ${aws_instance.main.public_ip}:3000 (admin/${var.grafana_admin_password})
  • Prometheus: ${aws_instance.main.public_ip}:9090
  • External Prometheus Endpoint: ${var.prometheus_endpoint}

📈 Dashboards Included:
  • Redis Software Basic Dashboards
  • Redis Software Extended Dashboards
  • All dashboards are automatically provisioned

🔧 Management:
  • SSH Access: ssh -i ~/.ssh/redis-observability ubuntu@${aws_instance.main.public_ip}
  • Status Check: /opt/redis-observability/status.sh

⚠️  Note: Initial setup may take 5-10 minutes to complete.
    All services will be automatically started and configured.

EOF
} 