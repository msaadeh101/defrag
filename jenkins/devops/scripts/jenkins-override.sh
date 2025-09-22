# Create override directory
sudo mkdir -p /etc/systemd/system/jenkins.service.d/

# Create custom override file
sudo tee /etc/systemd/system/jenkins.service.d/override.conf << EOF
[Unit]
# Add dependencies (e.g., wait for network and database)
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
# Custom Java options
Environment="JAVA_OPTS=-Xms4g -Xmx8g -XX:+UseG1GC -Djava.awt.headless=true"
Environment="JENKINS_OPTS=--httpPort=8080 --prefix=/jenkins"

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

# Restart policy
Restart=always
RestartSec=10

# Run as dedicated user with proper permissions
User=jenkins
Group=jenkins

# Security enhancements
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/lib/jenkins /var/log/jenkins

[Install]
WantedBy=multi-user.target
EOF

# Apply changes
sudo systemctl daemon-reload
sudo systemctl restart jenkins