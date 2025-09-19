#!/bin/bash

# IoT E-Waste Battery Monitoring - MQTT Broker Setup Script
# This script installs and configures Mosquitto MQTT broker on Raspberry Pi

echo "=== IoT E-Waste Battery Monitor - MQTT Broker Setup ==="
echo ""

# Update package list
echo "📦 Updating package list..."
sudo apt update

# Install Mosquitto MQTT broker and client tools
echo "🔧 Installing Mosquitto MQTT broker..."
sudo apt install -y mosquitto mosquitto-clients

# Create mosquitto configuration
echo "⚙️ Creating MQTT broker configuration..."
sudo tee /etc/mosquitto/conf.d/local.conf > /dev/null << EOF
# Local MQTT broker configuration for IoT E-Waste monitoring
listener 1883
allow_anonymous true
persistence true
persistence_location /var/lib/mosquitto/

# Logging
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true

# Security (for development - use authentication in production)
allow_anonymous true
EOF

# Enable and start Mosquitto service
echo "🚀 Starting Mosquitto service..."
sudo systemctl enable mosquitto
sudo systemctl restart mosquitto

# Check service status
echo "✅ Checking service status..."
sudo systemctl status mosquitto --no-pager -l

# Get Pi IP address
PI_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "📱 MQTT Broker Setup Complete!"
echo "🌐 Pi IP Address: $PI_IP"
echo "🔌 MQTT Port: 1883"
echo ""
echo "📋 Next Steps:"
echo "1. Update your Flutter app's MQTT broker IP to: $PI_IP"
echo "2. Run the battery monitoring script: python3 battery_9v_monitor.py"
echo "3. Test connection from Flutter app"
echo ""
echo "🧪 Test MQTT from command line:"
echo "Subscribe: mosquitto_sub -h $PI_IP -t 'iot_ewaste/+/+'"
echo "Publish: mosquitto_pub -h $PI_IP -t 'iot_ewaste/car001/test' -m 'Hello MQTT'"
