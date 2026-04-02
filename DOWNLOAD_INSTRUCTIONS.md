# 📦 Final Evolution Lab — Transfer to Mac Mini M4 Pro

## Method 1: Git Clone (Recommended — Fastest)

The project is hosted on GitHub. This is the simplest and most reliable way to get it on your Mac.

### Steps

```bash
# 1. Open Terminal on your Mac Mini

# 2. Clone the repository
git clone https://github.com/Elijahbonds/rork-final-evolution-lab.git

# 3. Enter the project directory
cd rork-final-evolution-lab

# 4. Verify
ls -la
```

> **Note:** If the repo is private, you'll need to authenticate with GitHub.
> Use `gh auth login` (GitHub CLI) or set up an SSH key / personal access token.

---

## Method 2: Download Archive from DeepAgent

A compressed archive (`FinalEvolutionLab_Project.tar.gz`, ~626 MB) is available.

### What's Included
- All source code, scripts, configs, Unreal project files
- SourceVideos (Instagram basketball footage)
- GeneratedAssets (Animations, Environments, CreatorAssets — excluding large Meshy/CV cache)
- Streaming infrastructure (signalling server, frontend)
- iOS app source
- Marketing site
- AI asset pipeline scripts
- All deployment guides and documentation

### What's Excluded (to keep size manageable)
- `.git/` history (use git clone for full history)
- `node_modules/` (reinstall with `npm install`)
- `GeneratedAssets/meshy/` (5.3 GB of Meshy API cache — regenerable)
- `GeneratedAssets/CVPreprocessed/` (245 MB — regenerable)
- `__pycache__/`, `.terraform/`

### Download Steps

1. **From DeepAgent UI:** Download the file `FinalEvolutionLab_Project.tar.gz` from the conversation artifacts.

2. **Extract on Mac:**
   ```bash
   cd ~/Desktop   # or wherever you want the project
   tar xzf ~/Downloads/FinalEvolutionLab_Project.tar.gz
   cd rork-final-evolution-lab
   ```

3. **Verify checksum:**
   ```bash
   shasum -a 256 ~/Downloads/FinalEvolutionLab_Project.tar.gz
   # Expected: f430f03e2a869e898e2a8dc50577b44f718fc3aa66f25dbd133755bedf7ddba9
   ```

4. **Restore Node dependencies:**
   ```bash
   cd streaming/signalling && npm install && cd ../..
   cd streaming/frontend && npm install && cd ../..
   cd sites/finalevolutiongroup.com && npm install && cd ../..
   ```

5. **Restore Python dependencies:**
   ```bash
   pip3 install -r scripts/ai_asset_pipeline/requirements.txt
   ```

6. **Set up environment variables:**
   ```bash
   cp scripts/ai_asset_pipeline/.env.example .env
   # Edit .env with your actual API keys
   ```

---

## Method 3: SCP / Direct Transfer (If Both Machines on Same Network)

If you have SSH access between DeepAgent and your Mac:

```bash
# From your Mac Mini terminal:
scp user@deepagent-ip:/home/ubuntu/FinalEvolutionLab_Project.tar.gz ~/Desktop/
```

---

## After Transfer: Quick Start on Mac Mini M4 Pro

### 1. Install Prerequisites
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js
brew install node

# Install Python 3
brew install python3

# Install Unreal Engine 5.4+ via Epic Games Launcher
# Download from: https://www.unrealengine.com/download
```

### 2. Verify Project Integrity
```bash
cd rork-final-evolution-lab
bash verify-project.sh
```

### 3. Open in Unreal Engine
```bash
# The .uproject file is at:
# UnrealStarter/BasketballGame/BasketballGame.uproject
# Double-click to open in UE5, or:
open UnrealStarter/BasketballGame/BasketballGame.uproject
```

### 4. Import AI Assets (in UE5 Editor)
- Open **Tools → Execute Python Script**
- Run `EditorPython/fel_import_ai_assets.py`
- Then run `EditorPython/fel_import_elijahbonds_animations.py`

### 5. Start Streaming Services (for testing)
```bash
bash scripts/start_services.sh
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `git clone` fails with 403 | Authenticate with `gh auth login` or use HTTPS with a personal access token |
| Archive won't extract | Re-download and verify checksum |
| `npm install` fails | Ensure Node.js 18+ is installed: `node --version` |
| UE5 can't open .uproject | Ensure UE 5.4+ is installed and file association is set |
| Missing GeneratedAssets/meshy | Run the AI pipeline: `python3 -m scripts.ai_asset_pipeline.local_first_pipeline` |
| Python import errors | `pip3 install -r scripts/ai_asset_pipeline/requirements.txt` |
| PEM files for AWS | Copy from `/home/ubuntu/Uploads/` — they're not in the repo for security |

---

## PEM Files (AWS Keys)

The `.pem` files uploaded to DeepAgent are **not included** in the archive or git repo for security.
Transfer them separately:

```bash
# On your Mac, create a secure location:
mkdir -p ~/.ssh/fel-keys
chmod 700 ~/.ssh/fel-keys

# Copy PEM files to that location and set permissions:
chmod 400 ~/.ssh/fel-keys/FinalEvolutionLab.pem
chmod 400 ~/.ssh/fel-keys/"Final Evolution Lab.pem"
```

---

## Video Files

The magic reveal videos uploaded to DeepAgent are also **not in the repo**.
Transfer them separately if needed for marketing/content:

```
Venice_Beach_Court_magic_reveal.mp4
Venice_Ball_Shop_magic_reveal.mp4
Muscle_beach_gym_magic_reveal.mp4
Muscle_beach_stage_magic_reveal.mp4
Venice_beach_tennis_courts_magic_reveal.mp4
Venice_Beach_Black_Top_magic_reveal.mp4
Hoopbus_magic_reveal.mp4
```
