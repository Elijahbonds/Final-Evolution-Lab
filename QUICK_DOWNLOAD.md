# 🚀 Quick Download Guide — Final Evolution Lab

## Why `git clone` Failed

The repository **`Elijahbonds/rork-final-evolution-lab`** is **private**. A plain `git clone` without authentication will return a "project missing" / 404 error.

You have **two options** to get the project:

---

## Option 1: Clone with Authentication (Recommended)

Use the GitHub access token to clone:

```bash
git clone https://x-access-token:YOUR_GITHUB_TOKEN@github.com/Elijahbonds/rork-final-evolution-lab.git
```

> **Note:** Replace `YOUR_GITHUB_TOKEN` with your actual GitHub Personal Access Token (PAT) that has `repo` scope access. You can generate one at: https://github.com/settings/tokens

Alternatively, if you have SSH set up:

```bash
git clone git@github.com:Elijahbonds/rork-final-evolution-lab.git
```

---

## Option 2: Download the Pre-Built Archive (626 MB)

A complete project archive is available for direct download.

### From DeepAgent VM (while session is active):

The file is being served at:

```
https://5233ce1ff-8080.na102.preview.abacusai.app/FinalEvolutionLab_Project.tar.gz
```

**On your Mac Mini M4 Pro, open Terminal and run:**

```bash
# Download the archive
cd ~/Desktop
curl -L -o FinalEvolutionLab_Project.tar.gz "https://5233ce1ff-8080.na102.preview.abacusai.app/FinalEvolutionLab_Project.tar.gz"

# Extract the archive
tar xzf FinalEvolutionLab_Project.tar.gz

# Verify the extraction
ls -la rork-final-evolution-lab/
```

### What's Inside the Archive

The archive contains the **complete project** including:

| Component | Description |
|-----------|-------------|
| `UnrealStarter/` | UE5 project with all C++ source, configs, and EditorPython scripts |
| `streaming/` | Signalling server + React frontend for Pixel Streaming |
| `ios/` | Swift iOS app with PixelStreamingService |
| `scripts/` | AI asset pipeline, UE5 setup, deployment scripts |
| `GeneratedAssets/` | Animation manifests, pipeline reports |
| `SourceVideos/` | Instagram video metadata for DeepMotion processing |
| `infrastructure/` | Docker, Terraform configs |
| `.env` | Environment variable template (fill in your API keys) |

---

## After Download: Verification

Run these checks to make sure everything extracted correctly:

```bash
cd rork-final-evolution-lab

# Check key files exist
ls UnrealStarter/BasketballGame/BasketballGame.uproject
ls streaming/signalling/server.js
ls streaming/frontend/package.json
ls ios/FinalEvolutionLab/Config.swift
ls scripts/ai_asset_pipeline/README.md

# Check file counts
echo "Total files: $(find . -type f | wc -l)"
```

You should see **all files present** and approximately **500+ files** total.

---

## Next Steps After Download

1. **Set up API keys** — Copy `.env.example` to `.env` and fill in your keys
2. **Install Node.js dependencies** — `cd streaming/signalling && npm install`
3. **Build the frontend** — `cd streaming/frontend && npm install && npm run build`
4. **Follow the Deployment Guide** — See `DEPLOYMENT_GUIDE.md` for full instructions
5. **For iOS** — Open `ios/` in Xcode, update signing, and build

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `curl` download fails | Make sure the DeepAgent session is still active |
| Permission denied on extract | Run `chmod -R u+rw rork-final-evolution-lab/` |
| Missing `.env` file | Copy from `.env.example` template |
| Git clone 404 error | Repo is private — use token auth (Option 1) |

---

*Generated: April 2, 2026*
