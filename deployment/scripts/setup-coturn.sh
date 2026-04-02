#!/bin/bash
# =============================================================================
# Final Evolution Lab - Dedicated TURN/STUN Server Setup
# =============================================================================
# Usage:
#   sudo ./setup-coturn.sh [realm] [secret]
#   sudo ./setup-coturn.sh stream.finalevolutiongroup.com mysecret123
# =============================================================================
set -euo pipefail

REALM="${1:-finalevolutiongroup.com}"
SECRET="${2:-$(openssl rand -hex 16)}"

echo "Setting up TURN/STUN server"
echo "Realm: $REALM"

# Install
apt-get update -qq
apt-get install -y -qq coturn

# Detect IPs
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com || curl -s http://ifconfig.me || echo "0.0.0.0")
PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo "Public IP:  $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"

# Configure
cat > /etc/turnserver.conf << EOF
# Final Evolution Lab TURN Server Configuration
realm=$REALM
server-name=$REALM
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=$SECRET

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
allowed-peer-ip=$PRIVATE_IP

# Logging
log-file=/var/log/turnserver.log
verbose
syslog

# Limits
total-quota=100
max-bps=0
bps-capacity=0
stale-nonce=600

# Performance
proc-quota-share=10
userdb=/var/lib/turn/turndb
EOF

# Enable
sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn
systemctl enable coturn
systemctl restart coturn

# Verify
if systemctl is-active coturn &>/dev/null; then
  echo ""
  echo "TURN server is running!"
  echo "  STUN URL:   stun:$PUBLIC_IP:3478"
  echo "  TURN URL:   turn:$PUBLIC_IP:3478"
  echo "  TURNS URL:  turns:$PUBLIC_IP:5349"
  echo "  Secret:     $SECRET"
  echo ""
  echo "  Save this secret for Pixel Streaming configuration."
else
  echo "ERROR: TURN server failed to start"
  journalctl -u coturn --no-pager -n 20
  exit 1
fi
