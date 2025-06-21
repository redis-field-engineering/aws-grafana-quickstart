terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Use existing VPC or create a new one
resource "aws_vpc" "main" {
  count                = var.vpc_id == "" ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Use existing subnet or create a new one
resource "aws_subnet" "main" {
  count                   = var.subnet_id == "" ? 1 : 0
  vpc_id                  = var.vpc_id != "" ? var.vpc_id : aws_vpc.main[0].id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-subnet"
  }
}

# Only create IGW and route table if creating VPC
resource "aws_internet_gateway" "main" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "main" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
  tags = {
    Name = "${var.project_name}-rt"
  }
}

resource "aws_route_table_association" "main" {
  count         = var.vpc_id == "" && var.subnet_id == "" ? 1 : 0
  subnet_id     = aws_subnet.main[0].id
  route_table_id = aws_route_table.main[0].id
}

# Security Group (always created, in correct VPC)
resource "aws_security_group" "main" {
  name_prefix = "${var.project_name}-sg"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : aws_vpc.main[0].id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Outbound rules
  # Allow Prometheus to scrape Redis Enterprise metrics on port 8070
  egress {
    from_port   = 8070
    to_port     = 8070
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Prometheus to scrape Redis Enterprise metrics"
  }
  
  # Allow all other outbound traffic (for package updates, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "${var.project_name}-sg"
  }
}

# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = var.subnet_id != "" ? var.subnet_id : aws_subnet.main[0].id
  user_data = templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
    prometheus_endpoint = var.prometheus_endpoint
    grafana_admin_password = var.grafana_admin_password
    dashboard_folders = join(" ", var.dashboard_folders)
  })
  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }
  tags = {
    Name = "${var.project_name}-instance"
  }
} 