# ⚡ Quick Start — Mac Mini M4 Pro

> **For experienced developers.** Condensed version of the full guides.  
> **Time: ~4 hours end-to-end** (mostly waiting for builds/downloads)

---

## 1. Prerequisites (10 min)

```bash
# Install tools
brew install awscli hashicorp/tap/terraform jq
xcode-select --install

# Configure AWS
aws configure  # Access Key, Secret Key, us-west-2, json

# Set billing alert ($400/month)
aws budgets create-budget --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{"BudgetName":"FEL","BudgetLimit":{"Amount":"400","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
  --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"YOUR_EMAIL"}]}]'
```

## 2. Get the Project (5 min)

```bash
mkdir -p ~/Projects && cd ~/Projects
git clone https://github.com/YOUR_USERNAME/rork-final-evolution-lab.git
cd rork-final-evolution-lab
cp .env.example .env && nano .env  # Add API keys
```

## 3. Install UE5 (45-90 min)

1. Download **Epic Games Launcher** from [unrealengine.com/download](https://www.unrealengine.com/download)
2. Install **UE 5.4** with **Linux target platform** enabled
3. Link GitHub account at [unrealengine.com/ue-on-github](https://www.unrealengine.com/ue-on-github)

```bash
# Set up environment
cat > .ue5_env << 'EOF'
export UE_ROOT="/Users/Shared/Epic Games/UE_5.4"
export UE_EDITOR="$UE_ROOT/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor"
export UE_CMD="$UE_ROOT/Engine/Binaries/Mac/UnrealEditor-Cmd"
export RUN_UAT="$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh"
export FEL_PROJECT="$(pwd)/UnrealStarter/BasketballGame/BasketballGame.uproject"
EOF
source .ue5_env
```

## 4. Build for Linux (1.5-3 hours)

```bash
# Open project first to compile shaders (~15 min)
open "$FEL_PROJECT"
# Import assets via Editor Python console, then close editor

# Package for Linux
caffeinate -i -s "$RUN_UAT" BuildCookRun \
  -project="$FEL_PROJECT" -noP4 -platform=Linux \
  -clientconfig=Shipping -serverconfig=Shipping \
  -cook -build -stage -pak -archive \
  -archivedirectory="$(pwd)/Builds/Linux" -compressed
```

## 5. Deploy to AWS (20 min)

```bash
# SSH key
ssh-keygen -t ed25519 -f ~/.ssh/fel-mac-mini -N ""
aws ec2 import-key-pair --key-name fel-mac-mini \
  --public-key-material fileb://~/.ssh/fel-mac-mini.pub --region us-west-2

# Terraform
cd deployment/aws
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Set region, instance type, key name, IP
terraform init && terraform apply

# Upload build
BUCKET=$(terraform output -raw s3_bucket_name)
cd ../.. && tar -czf Builds/fel-build.tar.gz -C Builds Linux/
aws s3 cp Builds/fel-build.tar.gz s3://$BUCKET/builds/ --region us-west-2

# Deploy
bash deployment/scripts/mac-deploy.sh
```

## 6. Verify

```bash
INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=final-evolution-lab" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region us-west-2)
curl http://$INSTANCE_IP:8888/healthz
open http://$INSTANCE_IP:80
```

## 7. Daily Operations

```bash
# Stop (saves ~$12/day)
aws ec2 stop-instances --instance-ids INSTANCE_ID --region us-west-2

# Start
aws ec2 start-instances --instance-ids INSTANCE_ID --region us-west-2

# SSH
ssh -i ~/.ssh/fel-mac-mini ubuntu@$INSTANCE_IP

# Full teardown
cd deployment/aws && terraform destroy
```

---

**Detailed guides:** [MAC_MINI_SETUP_GUIDE.md](MAC_MINI_SETUP_GUIDE.md) · [MAC_AWS_DEPLOYMENT.md](MAC_AWS_DEPLOYMENT.md) · [PROJECT_TRANSFER_GUIDE.md](PROJECT_TRANSFER_GUIDE.md) · [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)

*Last updated: April 2, 2026*
