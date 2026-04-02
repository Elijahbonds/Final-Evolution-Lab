# 📦 Project Transfer Guide — DeepAgent to Mac Mini M4 Pro

> **Transfer the Final Evolution Lab project from DeepAgent to your local Mac Mini M4 Pro**  
> **Project Size:** ~500 MB – 2 GB (depending on generated assets)  
> **Estimated Time:** 5–30 minutes (depending on method and connection speed)

---

## Table of Contents

1. [Option A: Download as ZIP from DeepAgent](#option-a-download-as-zip-from-deepagent) ⭐ Easiest
2. [Option B: Git Clone](#option-b-git-clone) ⭐ Recommended
3. [Option C: SCP/Rsync Transfer](#option-c-scprsync-transfer) 🔧 Advanced
4. [Option D: S3 Intermediate Transfer](#option-d-s3-intermediate-transfer) 🔧 Advanced
5. [Post-Transfer Verification](#post-transfer-verification)
6. [Troubleshooting](#troubleshooting)

---

## Option A: Download as ZIP from DeepAgent

**⭐ Easiest method — no command line needed**  
**⏱ Time: 5–15 minutes**

### Step 1: Download from DeepAgent UI

1. In the DeepAgent interface, locate the project files
2. Click the **"Download"** or **"Export"** button in the Code Editor UI
3. Select **"Download as ZIP"**
4. Wait for the ZIP to download to your Mac's `~/Downloads/` folder

### Step 2: Extract on Your Mac

```bash
# Create project directory
mkdir -p ~/Projects

# Extract the ZIP
cd ~/Projects
unzip ~/Downloads/rork-final-evolution-lab.zip

# Or if the ZIP has a different name
unzip ~/Downloads/rork-final-evolution-lab*.zip -d ~/Projects/
```

### Step 3: Verify

```bash
# Check project structure
ls ~/Projects/rork-final-evolution-lab/
# Should see: UnrealStarter/  scripts/  streaming/  deployment/  etc.

# Check key files exist
test -f ~/Projects/rork-final-evolution-lab/UnrealStarter/BasketballGame/BasketballGame.uproject && echo "✅ UE5 project file found" || echo "❌ Missing!"
test -d ~/Projects/rork-final-evolution-lab/deployment/aws && echo "✅ Terraform configs found" || echo "❌ Missing!"
test -d ~/Projects/rork-final-evolution-lab/streaming && echo "✅ Streaming infrastructure found" || echo "❌ Missing!"
```

---

## Option B: Git Clone

**⭐ Recommended — keeps version history and enables easy updates**  
**⏱ Time: 5–10 minutes**

### Prerequisites

- Git installed on your Mac (comes with Xcode Command Line Tools)
- GitHub account with access to the repository

### Step 1: Install Git (if needed)

```bash
# Check if Git is installed
git --version

# If not, install via Xcode Command Line Tools
xcode-select --install

# Or via Homebrew
brew install git
```

### Step 2: Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Step 3: Clone the Repository

```bash
mkdir -p ~/Projects
cd ~/Projects

# Clone via HTTPS
git clone https://github.com/YOUR_USERNAME/rork-final-evolution-lab.git

# OR clone via SSH (if you have SSH keys set up)
git clone git@github.com:YOUR_USERNAME/rork-final-evolution-lab.git
```

> **Replace `YOUR_USERNAME`** with the actual GitHub username/org.

### Step 4: Set Up Environment

```bash
cd ~/Projects/rork-final-evolution-lab

# Copy environment template
cp .env.example .env

# Edit with your API keys
nano .env
```

### Step 5: Verify

```bash
git status
git log --oneline -5
```

---

## Option C: SCP/Rsync Transfer

**🔧 Advanced — direct transfer if you have SSH access to DeepAgent VM**  
**⏱ Time: 10–30 minutes**

> This method requires SSH access to the DeepAgent VM. The PEM key files in your Uploads folder may be used for this.

### Step 1: Locate Your PEM Key

```bash
# Check for the PEM key on your Mac
ls ~/Downloads/*.pem
# Or wherever you saved the uploaded PEM files

# Set permissions
chmod 600 ~/Downloads/FinalEvolutionLab.pem
```

### Step 2: SCP Transfer (Simple)

```bash
mkdir -p ~/Projects

# Transfer entire project
scp -i ~/Downloads/FinalEvolutionLab.pem -r \
  ubuntu@DEEPAGENT_IP:/home/ubuntu/rork-final-evolution-lab \
  ~/Projects/
```

> **Replace `DEEPAGENT_IP`** with the DeepAgent VM's IP address.

### Step 3: Rsync Transfer (Better for Large Projects)

```bash
# Rsync with compression and progress (resumes interrupted transfers)
rsync -avz --progress \
  -e "ssh -i ~/Downloads/FinalEvolutionLab.pem" \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude 'Intermediate' \
  --exclude 'Saved' \
  --exclude '.terraform' \
  ubuntu@DEEPAGENT_IP:/home/ubuntu/rork-final-evolution-lab/ \
  ~/Projects/rork-final-evolution-lab/
```

### Step 4: Transfer Generated Assets Separately (if large)

```bash
# Transfer just the GeneratedAssets folder
rsync -avz --progress \
  -e "ssh -i ~/Downloads/FinalEvolutionLab.pem" \
  ubuntu@DEEPAGENT_IP:/home/ubuntu/rork-final-evolution-lab/GeneratedAssets/ \
  ~/Projects/rork-final-evolution-lab/GeneratedAssets/
```

---

## Option D: S3 Intermediate Transfer

**🔧 Advanced — useful if direct SCP is slow or unreliable**  
**⏱ Time: 15–30 minutes**

### On DeepAgent (or ask DeepAgent to run these):

```bash
# Install AWS CLI on DeepAgent (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Configure AWS credentials
aws configure

# Create a tarball of the project
cd /home/ubuntu
tar -czf rork-final-evolution-lab.tar.gz \
  --exclude='rork-final-evolution-lab/.git' \
  --exclude='rork-final-evolution-lab/node_modules' \
  --exclude='rork-final-evolution-lab/.terraform' \
  rork-final-evolution-lab/

# Upload to S3
aws s3 cp rork-final-evolution-lab.tar.gz s3://YOUR_BUCKET/transfer/rork-final-evolution-lab.tar.gz
```

### On Your Mac:

```bash
mkdir -p ~/Projects
cd ~/Projects

# Download from S3
aws s3 cp s3://YOUR_BUCKET/transfer/rork-final-evolution-lab.tar.gz .

# Extract
tar -xzf rork-final-evolution-lab.tar.gz

# Clean up
rm rork-final-evolution-lab.tar.gz

# Clean up S3 (to avoid storage costs)
aws s3 rm s3://YOUR_BUCKET/transfer/rork-final-evolution-lab.tar.gz
```

---

## Post-Transfer Verification

Run these checks after any transfer method:

```bash
cd ~/Projects/rork-final-evolution-lab

echo "=== Project Structure Check ==="
for dir in UnrealStarter streaming deployment scripts ios GeneratedAssets; do
  if [ -d "$dir" ]; then
    echo "✅ $dir/ exists"
  else
    echo "❌ $dir/ MISSING"
  fi
done

echo ""
echo "=== Key Files Check ==="
for file in \
  UnrealStarter/BasketballGame/BasketballGame.uproject \
  deployment/aws/main.tf \
  streaming/signalling/server.js \
  streaming/frontend/package.json \
  scripts/ue5_setup/cook_fel_linux_server.sh \
  DEPLOYMENT_CHECKLIST.md \
  MAC_MINI_SETUP_GUIDE.md \
  MAC_AWS_DEPLOYMENT.md; do
  if [ -f "$file" ]; then
    echo "✅ $file"
  else
    echo "❌ $file MISSING"
  fi
done

echo ""
echo "=== Project Size ==="
du -sh .

echo ""
echo "=== Generated Assets ==="
find GeneratedAssets -type f | wc -l | xargs -I{} echo "{} files in GeneratedAssets/"
```

### Expected Output

```
=== Project Structure Check ===
✅ UnrealStarter/ exists
✅ streaming/ exists
✅ deployment/ exists
✅ scripts/ exists
✅ ios/ exists
✅ GeneratedAssets/ exists

=== Key Files Check ===
✅ UnrealStarter/BasketballGame/BasketballGame.uproject
✅ deployment/aws/main.tf
✅ streaming/signalling/server.js
✅ streaming/frontend/package.json
✅ scripts/ue5_setup/cook_fel_linux_server.sh
✅ DEPLOYMENT_CHECKLIST.md
✅ MAC_MINI_SETUP_GUIDE.md
✅ MAC_AWS_DEPLOYMENT.md

=== Project Size ===
~500 MB - 2 GB

=== Generated Assets ===
XX files in GeneratedAssets/
```

---

## Troubleshooting

### ZIP Download is Too Large

If the project exceeds DeepAgent's download limit:

```bash
# Ask DeepAgent to create a smaller archive excluding large files
# Then transfer GeneratedAssets separately via S3
```

### Git Clone Fails — "Repository Not Found"

- Verify the repository URL is correct
- Check you have access (try opening the URL in a browser)
- Use HTTPS if SSH isn't configured:
  ```bash
  git clone https://github.com/YOUR_USERNAME/rork-final-evolution-lab.git
  ```

### SCP Connection Refused

- The DeepAgent VM may have shut down (VMs are temporary)
- Use Git clone or S3 transfer instead
- Check that the PEM file permissions are correct: `chmod 600 *.pem`

### Missing Files After Transfer

- Check `.gitignore` — some files may not be tracked:
  - `.env` (contains API keys — recreate from `.env.example`)
  - `node_modules/` (reinstall with `npm install`)
  - `.terraform/` (reinitialize with `terraform init`)
  - `Builds/` (rebuild with UE5)

```bash
# Reinstall Node dependencies
cd streaming/signalling && npm install
cd ../frontend && npm install

# Copy and configure .env
cp .env.example .env
nano .env

# Re-initialize Terraform
cd deployment/aws && terraform init
```

### Transfer Speed is Slow

```bash
# Use compression with rsync
rsync -avz --compress-level=9 ...

# Or split into smaller transfers
rsync -avz --include='UnrealStarter/***' --exclude='*' ...
rsync -avz --include='streaming/***' --exclude='*' ...
rsync -avz --include='deployment/***' --exclude='*' ...
```

---

*Last updated: April 2, 2026*
