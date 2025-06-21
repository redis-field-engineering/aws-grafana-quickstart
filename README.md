# Redis Observability - AWS Terraform Deployment

Terraform deployment for a Redis observability stack on AWS EC2. Creates an EC2 instance with Grafana and Prometheus, automatically provisioning Redis dashboards and connecting to your external Prometheus endpoint.

## What's Included

- **Grafana**: Web UI for dashboards (port 3000)
- **Prometheus**: Metrics collection and storage (port 9090)
- **Redis Dashboards**: Auto-provisioned basic and extended dashboards
- **External Integration**: Scrapes Redis Enterprise metrics endpoint

## Prerequisites

- Terraform v1.0.0 or later
- AWS CLI configured with appropriate credentials
- SSH key pair for EC2 access
- Connectivity to Redis prometheus endpoint

## Quick Start

1. **Generate SSH Key Pair**:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/redis-observability
   ```

2. **Copy and configure**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars** with your values:
   ```hcl
   aws_region = "us-west-2"
   project_name = "your-project-name"
   instance_type = "t3.medium"
   volume_size = 100
   ssh_public_key = "ssh-rsa AAAA..."
   prometheus_endpoint = "internal.c41255.us-west-2-mz.ec2.cloud.rlrcp.com:8070"
   grafana_admin_password = "your-secure-password"
   vpc_id = "vpc-xxxxxxxxx"
   subnet_id = "subnet-xxxxxxxxx"
   ```

4. **Deploy**:
   ```bash
   terraform init
   terraform apply
   ```

## Access

After deployment:
- **Grafana**: http://[PUBLIC_IP]:3000 (admin/[your-password])
- **Prometheus**: http://[PUBLIC_IP]:9090

## Configuration

### Required Variables
- `ssh_public_key`: SSH public key for EC2 access
- `prometheus_endpoint`: Redis Enterprise metrics endpoint (port 8070)
- `grafana_admin_password`: Admin password for Grafana

### Optional Variables
- `vpc_id` and `subnet_id`: Use existing VPC/subnet
- `instance_type`: EC2 instance type (default: t3.medium)
- `volume_size`: EBS volume size in GB (default: 100)

## Networking

The deployment creates a security group with:
- **Inbound**: SSH (22), Grafana (3000), Prometheus (9090)
- **Outbound**: Port 8070 (Redis metrics) + all traffic

Ensure network connectivity between EC2 and your Redis Enterprise metrics endpoint.

## Management

### Check Status
```bash
ssh -i ~/.ssh/redis-observability ubuntu@[PUBLIC_IP]
/opt/redis-observability/status.sh
```

### View Services
```bash
cd /opt/redis-observability
docker-compose ps
```

### View Logs
```bash
docker-compose logs -f grafana
docker-compose logs -f prometheus
```

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

### Services Not Accessible
1. Verify security group rules
2. Check Docker services: `docker-compose ps`
3. View logs: `docker-compose logs [SERVICE_NAME]`

### Prometheus Can't Scrape External Endpoint
1. Verify `prometheus_endpoint` URL is correct
2. Check network connectivity between EC2 and Redis cluster
3. Verify Redis Enterprise metrics endpoint is running
4. Check Prometheus targets: http://[PUBLIC_IP]:9090/targets

### Dashboards Not Loading
1. Verify Prometheus datasource in Grafana
2. Check if metrics are being scraped in Prometheus
3. Verify Redis Enterprise cluster is generating metrics

## Configuration

1. Copy the example configuration file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your specific values:
   - `ssh_public_key`: Your SSH public key for EC2 access
   - `prometheus_endpoint`: External Prometheus endpoint (e.g., `http://your-redis-enterprise-metrics:9090`)
   - `grafana_admin_password`: Admin password for Grafana
   - `vpc_id` and `subnet_id`: (Optional) Use existing VPC/subnet instead of creating new ones
   - `dashboard_folders`: (Optional) List of dashboard folder paths to copy from
   - `exclude_dashboards`: (Optional) List of dashboard filenames to exclude from loading

### Example Configuration

```hcl
aws_region = "us-west-2"
project_name = "redis-observability"
instance_type = "t3.medium"
volume_size = 20

ssh_public_key = "ssh-rsa AAAA..."
prometheus_endpoint = "http://your-redis-enterprise-metrics:9090"
grafana_admin_password = "your-secure-password"

# Optional: Use existing VPC/Subnet
# vpc_id = "vpc-12345678"
# subnet_id = "subnet-12345678"

# Optional: Configure which dashboard folders to copy from
dashboard_folders = [
  "dashboards/grafana_v9-11/software/basic",
  "dashboards/grafana_v9-11/software/extended"
]

# Optional: Exclude specific dashboards
exclude_dashboards = [
  "redis-software-active-active-dashboard_v9-11.json",
  "redis-software-synchronization-overview_v9-11.json"
]
```

### Dashboard Configuration Examples

**Copy only basic dashboards:**
```hcl
dashboard_folders = ["dashboards/grafana_v9-11/software/basic"]
```

**Copy from custom folder structure:**
```hcl
dashboard_folders = [
  "dashboards/grafana_v9-11/software/basic",
  "custom-dashboards/my-dashboards"
]
```

**Exclude specific dashboards:**
```hcl
exclude_dashboards = [
  "redis-software-cluster-dashboard_v9-11.json",
  "redis-software-database-dashboard_v9-11.json"
]
```

# aws-grafana-quickstart
