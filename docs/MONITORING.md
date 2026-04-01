# Monitoring & Maintenance Guide

## Health Checks

### Automated Health Monitoring Script

Save as `/opt/fel/health_check.sh` and run via cron every 5 minutes:

```bash
#!/bin/bash
ALERT_EMAIL="ops@finalevolutiongroup.com"
SLACK_WEBHOOK="https://hooks.slack.com/services/xxx"

check_service() {
    local name=$1 url=$2 expected=$3
    local status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url")
    if [ "$status" != "$expected" ]; then
        echo "ALERT: $name returned $status (expected $expected)"
        # Send alert via Slack/email
        curl -s -X POST "$SLACK_WEBHOOK" -d "{\"text\":\"🚨 $name is DOWN (HTTP $status)\"}" > /dev/null
    fi
}

# Check services
check_service "Signalling" "http://localhost:8888/healthz" "200"
check_service "Website" "https://finalevolutiongroup.com" "200"
check_service "Web App" "https://app.finalevolutiongroup.com" "200"

# Check GPU utilization
GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
if [ "$GPU_UTIL" != "N/A" ] && [ "$GPU_UTIL" -gt 95 ]; then
    echo "WARNING: GPU utilization at ${GPU_UTIL}%"
fi

# Check disk space
DISK_USED=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USED" -gt 85 ]; then
    echo "WARNING: Disk usage at ${DISK_USED}%"
fi
```

### Cron Setup
```bash
# Add to crontab
*/5 * * * * /opt/fel/health_check.sh >> /var/log/fel/health_check.log 2>&1
```

---

## Metrics to Monitor

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Signalling uptime | 99.9% | <99% |
| WebRTC latency | <30ms | >100ms |
| Stream quality | 1080p@60fps | <720p or <30fps |
| Active sessions | Track | >50 concurrent |
| GPU utilization | 40-80% | >95% |
| CPU utilization | <70% | >90% |
| Memory usage | <80% | >90% |
| Disk usage | <70% | >85% |
| SSL cert expiry | >30 days | <14 days |
| API response time | <200ms | >1000ms |

---

## Log Management

### Log Locations
```
/home/ubuntu/rork-final-evolution-lab/logs/          # Pipeline logs
streaming/signalling/logs/                            # Signalling server
streaming/frontend/logs/                              # Frontend
/var/log/nginx/                                       # Nginx access/error
/var/log/coturn/                                      # TURN server
```

### Log Rotation
```bash
# /etc/logrotate.d/fel
/home/ubuntu/rork-final-evolution-lab/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
}
```

---

## Maintenance Procedures

### Weekly
- [ ] Review error logs
- [ ] Check SSL certificate expiry dates
- [ ] Verify backup integrity
- [ ] Review active session metrics

### Monthly
- [ ] Update OS packages: `sudo apt update && sudo apt upgrade`
- [ ] Update Node.js dependencies: `npm audit fix`
- [ ] Review Cloudflare analytics
- [ ] Check GPU driver updates
- [ ] Run full integration test suite

### Quarterly
- [ ] Renew SSL certificates (if not auto-renewed)
- [ ] Review and update security policies
- [ ] Performance benchmarking
- [ ] Disaster recovery drill

---

## Backup Strategy

```bash
# Daily backup script
#!/bin/bash
BACKUP_DIR="/backups/fel/$(date +%Y-%m-%d)"
mkdir -p $BACKUP_DIR

# Source code
tar -czf $BACKUP_DIR/source.tar.gz \
  --exclude='node_modules' --exclude='.git' --exclude='Builds' \
  /home/ubuntu/rork-final-evolution-lab/

# Configuration
cp /etc/nginx/sites-available/finalevolution* $BACKUP_DIR/
cp /home/ubuntu/rork-final-evolution-lab/.env $BACKUP_DIR/

# Cleanup: keep 30 days
find /backups/fel/ -maxdepth 1 -mtime +30 -type d -exec rm -rf {} +
```

---

## Scaling Guide

### Horizontal Scaling (More Users)
1. Add more GPU instances behind load balancer
2. Use shared signalling server with session affinity
3. Configure CoTURN cluster with shared secret

### Vertical Scaling (Better Quality)
1. Upgrade GPU (T4 → A10G → A100)
2. Increase streaming resolution (1080p → 4K)
3. Increase target FPS (60 → 120)
