#!/bin/bash
set -e
exec > /var/log/fel-bootstrap.log 2>&1

echo "=== FEL Bootstrap Starting ==="
export DEBIAN_FRONTEND=noninteractive

mkdir -p /home/ubuntu/.fel
cat > /home/ubuntu/.fel/credentials.env << 'CREDS'
GITHUB_TOKEN=${github_token}
GAIA_API_KEY=${gaia_api_key}
LUMA_API_KEY=${luma_api_key}
RUNWAY_API_KEY=${runway_api_key}
STABILITY_API_KEY=${stability_api_key}
MESHY_API_KEY=${meshy_api_key}
NOTIFICATION_EMAIL=${notification_email}
SLACK_WEBHOOK=${slack_webhook}
CREDS
chmod 600 /home/ubuntu/.fel/credentials.env
chown -R ubuntu:ubuntu /home/ubuntu/.fel

apt-get update -y
apt-get install -y git curl wget

cd /home/ubuntu
if [ -n "${github_token}" ]; then
  git clone https://${github_token}@github.com/finalevolutiongroup/final-evolution-lab.git rork-final-evolution-lab || true
fi

if [ -d /home/ubuntu/rork-final-evolution-lab/deploy/aws ]; then
  chmod +x /home/ubuntu/rork-final-evolution-lab/deploy/aws/bootstrap.sh
  su - ubuntu -c '/home/ubuntu/rork-final-evolution-lab/deploy/aws/bootstrap.sh'
fi

echo "=== FEL Bootstrap Complete ==="
