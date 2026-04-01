# Troubleshooting Guide

## Common Issues

### 1. UE5 Build Issues

#### "No GPU detected"
- **Cause**: UE5 requires a GPU for rendering and Pixel Streaming
- **Fix**: Use a GPU-enabled machine (AWS g4dn/g5, GCP N1+T4, Azure NV series)
- **Workaround**: Build scripts and asset prep can run on CPU-only machines

#### "GitHub 403 when cloning UE5"
- **Cause**: GitHub account not linked to Epic Games
- **Fix**:
  1. Go to https://www.unrealengine.com/account/connections
  2. Link your GitHub account
  3. Accept the Epic Games organization invite
  4. Use a Personal Access Token: `git clone https://<PAT>@github.com/EpicGames/UnrealEngine.git`

#### Build fails with memory errors
- **Fix**: Ensure 32GB+ RAM; use `-MaxParallelActions 4` flag to reduce parallelism

---

### 2. Streaming Issues

#### WebSocket connection refused
```bash
# Check if signalling server is running
curl http://localhost:8888/healthz

# If not running:
cd streaming/signalling && npm start

# Check firewall
sudo ufw allow 8888
sudo ufw allow 443
```

#### Video stream not appearing
- Ensure UE5 server is running with `-PixelStreamingURL=ws://signalling:8888`
- Check browser console for WebRTC errors
- Verify TURN server is accessible: `turnutils_uclient turn.finalevolutiongroup.com`

#### High latency (>100ms)
- Move GPU server closer to users (same region)
- Check network congestion: `mtr <server_ip>`
- Reduce streaming resolution in UE5 config
- Enable hardware encoding (NVENC)

#### Black screen on mobile
- Check if H.264 is supported (iOS requires H.264)
- Verify WebRTC codec negotiation in browser console
- Test with VP8 fallback

---

### 3. iOS App Issues

#### Xcode signing errors
```
# Verify provisioning profile
security find-identity -v -p codesigning

# Clean build folder
xcodebuild clean -workspace FinalEvolutionLab.xcworkspace -scheme FinalEvolutionLab
```

#### App crashes on launch
- Check `Config.swift` URLs are correct
- Verify minimum iOS version is 16.0
- Check for missing privacy descriptions in Info.plist

#### Cannot connect to streaming server
- Verify ATS exceptions in Info.plist
- Check if `stream.finalevolutiongroup.com` resolves on device
- Test WebSocket connection: open Safari → `wss://stream.finalevolutiongroup.com`

---

### 4. DNS Issues

#### Domain not resolving
```bash
# Check propagation
dig @8.8.8.8 finalevolutiongroup.com
dig @1.1.1.1 stream.finalevolutiongroup.com

# Check nameservers
dig NS finalevolutiongroup.com

# Flush local DNS cache
sudo systemd-resolve --flush-caches  # Linux
sudo dscacheutil -flushcache          # macOS
```

#### SSL certificate errors
- Verify cert covers all subdomains
- Check Cloudflare SSL mode matches server config
- Ensure stream/turn subdomains are not proxied through Cloudflare

---

### 5. Docker Issues

#### Container won't start
```bash
# Check logs
docker-compose logs -f signalling
docker-compose logs -f coturn

# Rebuild
docker-compose build --no-cache
docker-compose up -d
```

#### Port conflicts
```bash
# Find process using port
lsof -i :8888
lsof -i :3478

# Kill process
kill $(lsof -ti:8888)
```

---

### 6. Asset Pipeline Issues

#### DeepMotion API errors
- Verify `DEEPMOTION_CLIENT_ID` and `DEEPMOTION_CLIENT_SECRET` in `.env`
- Check API quota at https://www.deepmotion.com/dashboard
- Run `python scripts/process_elijahbonds_animations.py --test-auth`

#### Meshy generation failures
- Verify `MESHY_API_KEY` in `.env`
- Check task status: `python -c "from scripts.ai_asset_pipeline.meshy_service import MeshyService; ..."`
- API rate limit: wait 60s between requests

#### Missing assets in UE5
- Run `python scripts/ue5_setup/fel_verify_assets_standalone.py`
- Check `GeneratedAssets/pipeline_report.json` for failures
- Re-run import: `python UnrealStarter/BasketballGame/EditorPython/fel_import_ai_assets.py`

---

## Emergency Procedures

### Service Recovery
```bash
# Restart all services
./scripts/stop_services.sh
./scripts/start_services.sh

# Docker recovery
docker-compose down
docker-compose up -d

# Check health
curl http://localhost:8888/healthz
```

### Rollback
```bash
# Git rollback to last known good state
git log --oneline -10
git checkout <commit_hash>

# Rebuild
npm run build  # frontend
./scripts/start_services.sh
```
