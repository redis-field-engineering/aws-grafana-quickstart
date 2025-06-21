variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "redis-observability"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instance access"
  type        = string
}

variable "prometheus_endpoint" {
  description = "External Prometheus endpoint URL (e.g., http://prometheus.example.com:9090)"
  type        = string
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "vpc_id" {
  description = "(Optional) Existing VPC ID to use. If not set, a new VPC will be created."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "(Optional) Existing Subnet ID to use. If not set, a new subnet will be created."
  type        = string
  default     = ""
}


variable "dashboard_folders" {
  description = "List of dashboard folder paths to copy from (relative to the repo root)"
  type        = list(string)
  default     = [
    "grafana/dashboards/grafana_v9-11/software/",
    "grafana/dashboards/grafana_v9-11/workflow/"
  ]
} 