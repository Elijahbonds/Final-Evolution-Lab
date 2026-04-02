# Final Evolution Lab — Deployment Infrastructure

Production-ready UE5 Pixel Streaming deployment on AWS with GPU instances, auto-scaling, monitoring, and blue-green deployments.

## Quick Start

```bash
# 1. Configure
cp aws/terraform.tfvars.example aws/terraform.tfvars
# Edit terraform.tfvars

# 2. Deploy Infrastructure
cd aws && terraform init && terraform apply

# 3. Build & Upload UE5
cd ../scripts && ./build-and-upload.sh --config Shipping

# 4. Deploy to Fleet
./deploy-fleet.sh
```

## Structure

| Directory | Purpose |
|-----------|---------|
| `aws/` | Terraform infrastructure (VPC, EC2, ALB, ASG, S3, CloudWatch, IAM) |
| `scripts/` | Operational scripts (build, deploy, health check, monitoring) |
| `docs/` | Comprehensive deployment guide |

## SSH Access

```bash
# Primary key
ssh -i ~/Uploads/FinalEvolutionLab.pem ubuntu@<INSTANCE_IP>

# Alternate key
ssh -i ~/Uploads/"Final Evolution Lab.pem" ubuntu@<INSTANCE_IP>
```

## Full Documentation

See [docs/UE5_DEPLOYMENT_GUIDE.md](docs/UE5_DEPLOYMENT_GUIDE.md) for the complete step-by-step guide including:
- Architecture overview
- Cost estimates for different scales
- Scaling guide
- Monitoring setup
- Security best practices
- Troubleshooting
- Backup & disaster recovery
