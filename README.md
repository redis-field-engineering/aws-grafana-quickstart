# Redis Observability - AWS Terraform Deployment

This directory contains a Terraform-based deployment for setting up a Redis observability stack on AWS EC2. The deployment creates an EC2 instance with Grafana and Prometheus, automatically provisioning Redis dashboards and connecting to your external Prometheus endpoint.

## Getting AWS Resource IDs with AWS CLI

If you want to use an existing VPC or subnet, you can retrieve their IDs using the AWS CLI:

### Get VPC IDs
```bash
aws ec2 describe-vpcs --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`]|[0].Value}' --output table
```

### Get Subnet IDs (for a given VPC)
```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<your-vpc-id>" --query 'Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,Name:Tags[?Key==`Name`]|[0].Value}' --output table
```

### Get Project Name (from EC2 instance tags, if you have one running)
```bash
aws ec2 describe-instances --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' --output text
```

Replace `<your-vpc-id>` with the VPC ID you want to use.



## What's Included

### 📊 **Grafana Dashboards**
- **Redis Basic Dashboards**: Database, Node, Cluster, Shard, Active-Active
- **Redis Extended Dashboards**: Enhanced monitoring and detailed metrics
- **Auto-provisioned**: All dashboards are automatically loaded and configured

### **Services**
- **Grafana**: Web UI for dashboards (port 3000)
- **Prometheus**: Metrics collection and storage (port 9090)
- **External Integration**: Scrapes your Redis Enterprise metrics endpoint

## Prerequisites

- Terraform v1.0.0 or later
- AWS CLI configured with appropriate credentials
- SSH key pair for EC2 access
- Connectivity to a Redis prometheus endpoint

## Networking Requirements

### **Prometheus Connectivity**
The EC2 instance needs to connect to your Redis Enterprise metrics endpoint on **port 8070**. Ensure:

- **VPC Peering** or **Transit Gateway** is configured between your VPCs
- **Route tables** are updated to route traffic between VPCs
- **Security groups** on the Redis Enterprise side allow inbound traffic on port 8070 from the EC2 instance

### **Security Group Configuration**
The deployment creates a security group that:
- **Inbound**: SSH (22), Grafana (3000), Prometheus (9090)
- **Outbound**: Port 8070 (Redis metrics) + all other traffic

## Quick Start

1. **Generate SSH Key Pair** (if you don't have one):
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/redis-observability
   ```

2. **Copy the example configuration**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars** with your values:
   ```hcl
   aws_region = "us-west-2"
   project_name = "redis-observability"
   instance_type = "t3.medium"
   volume_size = 20
   ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..."
   
   # Your Redis Enterprise metrics endpoint
   prometheus_endpoint = "internal.c47755.us-west-2-mz.ec2.cloud.rlrcp.com:8070"
   
   # Grafana admin password
   grafana_admin_password = "your-secure-password"

   # Use existing VPC and subnet (optional)
   # vpc_id = "vpc-00000000000000000"
   # subnet_id = "subnet-00000000000000000"
   ```

4. **Initialize Terraform**:
   ```bash
   terraform init
   ```

5. **Deploy the infrastructure**:
   ```bash
   terraform apply
   ```

6. **Wait for deployment** (takes 5-10 minutes for full setup)

## Accessing the Services

After deployment, you can access:

- **Grafana**: http://[PUBLIC_IP]:3000 (admin/[your-password])
- **Prometheus**: http://[PUBLIC_IP]:9090

## Configuration Details

### Prometheus Configuration
The deployment creates a Prometheus instance that:
- Scrapes your external Redis Enterprise metrics endpoint
- Stores metrics locally for 200 hours
- Provides a web interface for querying metrics

### Grafana Configuration
Grafana is configured with:
- Pre-configured Prometheus datasource
- Auto-provisioned Redis dashboards
- Custom admin password
- Persistent storage

## SSH Access

To SSH into the instance:
```bash
ssh -i ~/.ssh/redis-observability ubuntu@[PUBLIC_IP]
```

## Monitoring and Management

### Check Service Status
SSH into the instance and run:
```bash
/opt/redis-observability/status.sh
```

### View Docker Services
```bash
cd /opt/redis-observability
docker-compose ps
```

### View Logs
```bash
cd /opt/redis-observability
docker-compose logs -f grafana
docker-compose logs -f prometheus
```

## Customization

### Instance Type
Modify `instance_type` in `terraform.tfvars`:
- `t3.small`: 2 vCPU, 2 GB RAM (minimal)
- `t3.medium`: 2 vCPU, 4 GB RAM (recommended)
- `t3.large`: 2 vCPU, 8 GB RAM (for larger workloads)

### Volume Size
Adjust `volume_size` in `terraform.tfvars` based on your storage needs.

### Region
Change `aws_region` to deploy in your preferred AWS region.

### Prometheus Endpoint
Set `prometheus_endpoint` to your Redis Enterprise metrics endpoint (typically port 8070).

## Security Considerations

- The security group opens Grafana (3000), Prometheus (9090), and SSH (22) ports
- Consider restricting access to specific IP ranges for production use
- Use strong passwords for Grafana admin account
- Enable AWS CloudTrail for audit logging

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Troubleshooting

### Instance Not Starting
1. Check the instance status in AWS Console
2. View system logs: `aws ec2 get-console-output --instance-id [INSTANCE_ID]`

### Services Not Accessible
1. Verify security group rules
2. Check if Docker services are running: `docker-compose ps`
3. View service logs: `docker-compose logs [SERVICE_NAME]`

### Prometheus Can't Scrape External Endpoint
1. Verify the `prometheus_endpoint` URL is correct and accessible
2. Check network connectivity between EC2 and your Redis cluster
3. Verify Redis Enterprise metrics endpoint is running and accepting connections
4. Check Prometheus targets page: http://[PUBLIC_IP]:9090/targets

### Dashboards Not Loading
1. Verify Prometheus datasource is working in Grafana (this will be a local docker compose service name)
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
