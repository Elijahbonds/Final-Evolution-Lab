#!/bin/bash
# =============================================================================
# Final Evolution Lab - TURN/STUN Server Bootstrap
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/fel-turn-bootstrap.log) 2>&1

echo "Setting up TURN/STUN server (coturn)..."

export DEBIAN_FRONTEND=noninteractive

# Install coturn
apt-get update -qq
apt-get install -y -qq coturn

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "")
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Configure coturn
cat > /etc/turnserver.conf << TURNEOF
# TURN server configuration for Final Evolution Lab
realm=${realm}
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=${turn_secret}

# Network
listening-port=3478
tls-listening-port=5349
listening-ip=$PRIVATE_IP
external-ip=$PUBLIC_IP/$PRIVATE_IP
relay-ip=$PRIVATE_IP
min-port=49152
max-port=65535

# Security
no-multicast-peers
no-cli
no-tlsv1
no-tlsv1_1
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255

# Logging
log-file=/var/log/turnserver.log
verbose

# Performance
total-quota=100
max-bps=0
stale-nonce=600
TURNEOF

# Enable coturn
sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

systemctl enable coturn
systemctl restart coturn

echo "TURN server setup complete. Public IP: $PUBLIC_IP"
