# Final Evolution Lab — Manual AWS Provisioning Guide

## Prerequisites
- AWS Account with access to G5 instances
- EC2 Key Pair created in your target region
- Basic familiarity with AWS Console

---

## Step 1: Launch EC2 Instance

1. Go to **EC2 → Launch Instance**
2. Configure:
   - **Name**: `FinalEvolutionLab-Build`
   - **AMI**: Ubuntu Server 22.04 LTS (64-bit x86)
   - **Instance type**: `g5.2xlarge` (1 NVIDIA A10G GPU, 8 vCPU, 32GB RAM)
   - **Key pair**: Select your key pair
   - **Network**:
     - Create new VPC or use default
     - Enable "Auto-assign public IP"
   - **Storage**: 500 GB gp3 (IOPS: 6000, Throughput: 400 MB/s)
   - **Security Group**: Create new with these rules:

| Type   | Port Range  | Source    | Description            |
|--------|------------|-----------|------------------------|
| SSH    | 22         | Your IP   | SSH access             |
| HTTP   | 80         | 0.0.0.0/0 | Website                |
| HTTPS  | 443        | 0.0.0.0/0 | SSL                    |
| Custom | 3000       | 0.0.0.0/0 | Web Frontend           |
| Custom | 8888-8889  | 0.0.0.0/0 | Pixel Streaming        |
| Custom | 3478       | 0.0.0.0/0 | TURN TCP               |
| UDP    | 3478       | 0.0.0.0/0 | TURN UDP               |
| UDP    | 49152-49200| 0.0.0.0/0 | Media Relay            |

3. **Launch Instance**

## Step 2: Allocate Elastic IP

1. Go to **EC2 → Elastic IPs → Allocate**
2. Associate with your instance
3. Note the IP: `_______________`

## Step 3: Create IAM Role (Optional)

1. Go to **IAM → Roles → Create Role**
2. Trusted entity: EC2
3. Attach policies:
   - `AmazonS3FullAccess`
   - `CloudWatchAgentServerPolicy`
4. Name: `FEL-InstanceRole`
5. Attach to instance: EC2 → Instance → Actions → Security → Modify IAM role

## Step 4: Connect & Setup

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@YOUR_ELASTIC_IP

# Transfer project (from your local machine)
scp -r -i your-key.pem /path/to/rork-final-evolution-lab ubuntu@YOUR_ELASTIC_IP:/home/ubuntu/

# Or clone from GitHub
export GITHUB_TOKEN="ghp_your_token"
git clone https://${GITHUB_TOKEN}@github.com/finalevolutiongroup/final-evolution-lab.git rork-final-evolution-lab

# Run bootstrap
cd /home/ubuntu/rork-final-evolution-lab
chmod +x deploy/aws/bootstrap.sh
./deploy/aws/bootstrap.sh

# After bootstrap completes, run the pipeline
./deploy/aws/deploy_final_evolution_lab.sh --build --deploy
```

## Step 5: Transfer Project from Current VM

If you have the project on another machine:

```bash
# Option A: rsync (fastest, supports resume)
rsync -avz --progress -e 'ssh -i key.pem' \
  /home/ubuntu/rork-final-evolution-lab \
  ubuntu@YOUR_IP:/home/ubuntu/

# Option B: tar + scp
cd /home/ubuntu
tar czf fel-project.tar.gz rork-final-evolution-lab \
  --exclude='node_modules' --exclude='.git' --exclude='Builds'
scp -i key.pem fel-project.tar.gz ubuntu@YOUR_IP:/home/ubuntu/
# Then on remote: tar xzf fel-project.tar.gz

# Option C: S3 intermediate
aws s3 cp --recursive rork-final-evolution-lab s3://your-bucket/fel/
# On remote:
aws s3 cp --recursive s3://your-bucket/fel/ rork-final-evolution-lab
```

## Step 6: Set Credentials

```bash
# Edit .env file
nano /home/ubuntu/rork-final-evolution-lab/.env

# Required:
GITHUB_TOKEN=ghp_...           # Epic Games GitHub PAT
MESHY_API_KEY=msy_...          # Meshy AI key
LUMA_API_KEY=...               # Luma AI key

# Optional:
GAIA_API_KEY=...               # Gaia API
RUNWAY_API_KEY=...             # Runway API
STABILITY_API_KEY=...          # Stability AI
NOTIFICATION_EMAIL=you@...     # Email alerts
SLACK_WEBHOOK=https://hooks... # Slack alerts
```

## Step 7: Run Pipeline

```bash
# Interactive mode (recommended for first run)
./deploy/aws/deploy_final_evolution_lab.sh --interactive

# Or direct
./deploy/aws/deploy_final_evolution_lab.sh --build --deploy

# Monitor progress
./deploy/aws/monitor_dashboard.sh --watch
```

## Cost Estimate

| Resource          | Cost/Hour | Monthly (24/7) |
|-------------------|-----------|----------------|
| g5.2xlarge        | ~$1.21    | ~$871          |
| 500GB gp3 EBS     | ~$0.055/h | ~$40           |
| Elastic IP        | Free      | Free (in use)  |
| Data Transfer     | ~$0.09/GB | Varies         |
| **Total Build**   | **~$1.27/h** | -           |

**Tip**: Build takes ~4-8 hours. Stop instance when not in use!

```bash
# Stop to save money (preserves EBS)
aws ec2 stop-instances --instance-ids i-xxx
# Start when needed
aws ec2 start-instances --instance-ids i-xxx
```
