
#!/bin/bash
# user_data.sh - Script executed on instance boot

# Update system
apt-get update
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    nginx \
    docker.io \
    docker-compose \
    awscli \
    jq

# Configure hostname
hostnamectl set-hostname ${hostname}
echo "127.0.0.1 ${hostname}" >> /etc/hosts

# Start and enable services
systemctl start nginx
systemctl enable nginx
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install Alibaba Cloud CLI
curl -fsSL https://aliyuncli.alicdn.com/install.sh | bash
ln -s /root/.local/bin/aliyun /usr/local/bin/aliyun

# Configure nginx with basic health check
cat > /var/www/html/health << 'EOF'
{
    "status": "healthy",
    "hostname": "${hostname}",
    "timestamp": "$(date -Iseconds)"
}
EOF

# Basic nginx configuration
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name _;
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Default location
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

# Restart nginx
systemctl restart nginx

# Install CloudWatch agent equivalent (Alibaba Cloud Monitor)
wget https://cms-agent-${region}.oss-${region}.aliyuncs.com/release/cms_go_agent/cms_go_agent_linux-amd64.tar.gz
tar -xzf cms_go_agent_linux-amd64.tar.gz
chmod +x cms_go_agent_linux-amd64
./cms_go_agent_linux-amd64 start

# Create a simple web page showing instance info
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Instance Info</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .info { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .healthy { color: green; }
    </style>
</head>
<body>
    <h1>Alibaba Cloud Instance</h1>
    <div class="info">
        <h3>Instance Information</h3>
        <p><strong>Hostname:</strong> ${hostname}</p>
        <p><strong>Instance ID:</strong> <span id="instance-id">Loading...</span></p>
        <p><strong>Region:</strong> ${region}</p>
        <p><strong>Status:</strong> <span class="healthy">Running</span></p>
        <p><strong>Last Updated:</strong> <span id="timestamp"></span></p>
    </div>
    
    <script>
        // Get instance metadata
        fetch('/health')
            .then(response => response.text())
            .then(data => {
                document.getElementById('timestamp').textContent = new Date().toISOString();
            })
            .catch(error => {
                document.getElementById('timestamp').textContent = 'Error loading';
            });
            
        // Try to get instance ID from metadata service
        fetch('http://100.100.100.200/latest/meta-data/instance-id')
            .then(response => response.text())
            .then(data => {
                document.getElementById('instance-id').textContent = data;
            })
            .catch(error => {
                document.getElementById('instance-id').textContent = 'Not available';
            });
    </script>
</body>
</html>
EOF

# Set up log rotation for application logs
cat > /etc/logrotate.d/webapp << 'EOF'
/var/log/webapp/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
}
EOF

# Create webapp log directory
mkdir -p /var/log/webapp
chown ubuntu:ubuntu /var/log/webapp

# Install and configure fail2ban
apt-get install -y fail2ban
systemctl start fail2ban
systemctl enable fail2ban

# Basic fail2ban configuration
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl restart fail2ban

# Set up automatic security updates
apt-get install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades

# Signal that user data script completed successfully
touch /var/log/user-data-complete
echo "User data script completed at $(date)" >> /var/log/user-data.log