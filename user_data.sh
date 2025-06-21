#!/bin/bash

# Disable IPv6 to prevent connectivity issues
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

# Update system and install packages
apt-get update && apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git jq unzip

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl start docker && systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create application directory and clone repository
mkdir -p /opt/redis-observability && cd /opt/redis-observability
git clone https://github.com/redis-field-engineering/redis-enterprise-observability.git .

# Create docker-compose.yml
cat > docker-compose.yml << EOF
version: '3.8'
services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports: ["3000:3000"]
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${grafana_admin_password}
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
    networks: [monitoring]

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports: ["9090:9090"]
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    volumes:
      - prometheus-storage:/prometheus
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks: [monitoring]

networks:
  monitoring:
    driver: bridge

volumes:
  grafana-storage:
  prometheus-storage:
EOF

# Create Prometheus configuration
cat > prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs: [{targets: ['localhost:9090']}]
  - job_name: 'redis'
    scrape_interval: 30s
    scrape_timeout: 30s
    metrics_path: /
    scheme: https
    tls_config: {insecure_skip_verify: true}
    static_configs: [{targets: ['${prometheus_endpoint}']}]
EOF

# Create Grafana provisioning
mkdir -p grafana/provisioning/{datasources,dashboards} grafana/dashboards

cat > grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1
datasources:
  - name: Prometheus
    uid: redis-prometheus-datasource
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

cat > grafana/provisioning/dashboards/dashboards.yml << EOF
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options: {path: /etc/grafana/provisioning/dashboards}
EOF

# Copy dashboard files
for folder in ${dashboard_folders}; do
    if [ -d "$folder" ]; then
        find "$folder" -name "*.json" -type f -exec cp {} grafana/dashboards/ \;
    fi
done

# Download dashboards if none copied
if [ ! "$(ls -A grafana/dashboards/*.json 2>/dev/null)" ]; then
    cd grafana/dashboards
    for folder in ${dashboard_folders}; do
        github_path=$(echo "$folder" | sed 's|^grafana/dashboards/||')
        curl -s "https://api.github.com/repos/redis-field-engineering/redis-enterprise-observability/contents/$github_path" | jq -r '.[] | select(.type == "file" and .name | endswith(".json")) | .name' | while read filename; do
            [ -n "$filename" ] && curl -O "https://raw.githubusercontent.com/redis-field-engineering/redis-enterprise-observability/main/$github_path/$filename"
        done
    done
    cd ../..
fi

# Update datasource references
echo "Updating datasource references in dashboard files..."
find grafana/dashboards -name "*.json" -exec sed -i 's/"uid": "$$$${DS_PROMETHEUS}"/"uid": "redis-prometheus-datasource"/g' {} \;
find grafana/dashboards -name "*.json" -exec sed -i 's/"uid": "$${DS_PROMETHEUS}"/"uid": "redis-prometheus-datasource"/g' {} \;
find grafana/dashboards -name "*.json" -exec sed -i 's/"datasource": "$$$${DS_PROMETHEUS}"/"datasource": "redis-prometheus-datasource"/g' {} \;
find grafana/dashboards -name "*.json" -exec sed -i 's/"datasource": "$${DS_PROMETHEUS}"/"datasource": "redis-prometheus-datasource"/g' {} \;

# Verify all datasource references are fixed
echo "Verifying datasource references are fixed..."
find grafana/dashboards -name "*.json" -exec grep -l "DS_PROMETHEUS" {} \; | while read file; do
    echo "Warning: $file still contains DS_PROMETHEUS references"
done

# Start services
docker-compose up -d
docker-compose restart grafana

# Wait for Grafana and import dashboards
until curl -s http://admin:${grafana_admin_password}@localhost:3000/api/health >/dev/null; do sleep 5; done

# Import dashboards via API as backup
echo "Importing dashboards via API..."
for file in grafana/dashboards/*.json; do
    if [ -f "$file" ]; then
        echo "Importing: $(basename "$file")"
        # Use temporary file to avoid command line length issues
        DASHBOARD_JSON=$(cat "$file" | sed 's/"uid": "$$$${DS_PROMETHEUS}"/"uid": "redis-prometheus-datasource"/g' | sed 's/"uid": "$${DS_PROMETHEUS}"/"uid": "redis-prometheus-datasource"/g' | sed 's/"datasource": "$$$${DS_PROMETHEUS}"/"datasource": "redis-prometheus-datasource"/g' | sed 's/"datasource": "$${DS_PROMETHEUS}"/"datasource": "redis-prometheus-datasource"/g')
        API_PAYLOAD=$(echo "{ \"dashboard\": $DASHBOARD_JSON, \"folderId\": 0, \"message\": \"Provisioned via Terraform\", \"overwrite\": true }")
        
        # Save to temporary file to avoid command line length issues
        echo "$API_PAYLOAD" > /tmp/dashboard_import.json
        curl -s -X POST "http://admin:${grafana_admin_password}@localhost:3000/api/dashboards/db" \
             --header 'Content-Type: application/json' --data @/tmp/dashboard_import.json >/dev/null
        rm -f /tmp/dashboard_import.json
    fi
done

# Create status script
cat > /opt/redis-observability/status.sh << EOF
#!/bin/bash
echo "=== Redis Observability Status ==="
echo "Grafana: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "Prometheus: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090"
echo "External Prometheus Endpoint: ${prometheus_endpoint}"
echo ""
echo "=== Docker Services Status ==="
docker-compose ps
EOF
chmod +x /opt/redis-observability/status.sh

# Create systemd service
cat > /etc/systemd/system/redis-observability.service << EOF
[Unit]
Description=Redis Observability Stack
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/redis-observability
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0
[Install]
WantedBy=multi-user.target
EOF

systemctl enable redis-observability.service
systemctl start redis-observability.service

echo "Redis Observability setup completed!"
echo "Grafana: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000 (admin/${grafana_admin_password})"
echo "Prometheus: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9090" 