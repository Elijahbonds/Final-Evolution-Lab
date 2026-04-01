# iOS App Store Submission Checklist

## Pre-Submission Requirements

### App Configuration
- [ ] Bundle ID: `com.finalevolutiongroup.lab`
- [ ] App Version: 1.0.0
- [ ] Build Number: incremented for each submission
- [ ] Minimum iOS: 16.0
- [ ] Supported devices: iPhone only (or Universal)
- [ ] Supported orientations: Portrait + Landscape

### Code Signing
- [ ] Apple Developer Program membership active ($99/year)
- [ ] Distribution certificate created
- [ ] App Store provisioning profile created
- [ ] Entitlements configured:
  - [ ] HealthKit
  - [ ] Multicast Networking
  - [ ] Push Notifications

### Privacy
- [ ] Camera usage description in Info.plist
- [ ] Motion & Fitness usage description
- [ ] HealthKit usage description
- [ ] Local Network usage description
- [ ] Microphone usage description (if used)
- [ ] App Privacy Nutrition Labels completed in App Store Connect

### App Transport Security
- [ ] ATS exceptions for `finalevolutiongroup.com` domains
- [ ] All production endpoints use HTTPS
- [ ] WebSocket connections use WSS

---

## App Store Connect Setup

### App Information
- [ ] App name: "Final Evolution Lab"
- [ ] Subtitle: "Athletic Training Through Gaming"
- [ ] Category: Health & Fitness (primary), Games - Sports (secondary)
- [ ] Content rating: 4+ (no objectionable content)

### Description
```
Final Evolution Lab transforms your phone into an elite athletic training platform.

Train with 16 competitive game modes powered by real motion-captured animations from pro athletes. From basketball to karate, soccer to boxing — every sport features real physics and real-time 3D graphics streamed to your device.

FEATURES:
• 16 Game Modes — Basketball, Karate, Soccer, Boxing, Tennis, and more
• 23 Motion-Captured Exercises — AI-powered form tracking
• Real-Time 3D Streaming — Console-quality UE5 graphics on your phone
• Competitive Multiplayer — Challenge friends in head-to-head matches
• Performance Analytics — Track your progress with detailed stats
• HealthKit Integration — Sync workouts to Apple Health

Powered by Unreal Engine 5 Pixel Streaming technology for sub-30ms latency gaming.
```

### Keywords
```
fitness,gaming,workout,basketball,karate,exercise,sports,training,3D,streaming
```

### Screenshots Required
- [ ] 6.7" (iPhone 15 Pro Max): 1290 x 2796 — min 3, max 10
- [ ] 6.5" (iPhone 14 Plus): 1284 x 2778 — min 3, max 10
- [ ] 5.5" (iPhone 8 Plus): 1242 x 2208 — min 3, max 10
- [ ] iPad Pro 12.9": 2048 x 2732 (if supporting iPad)

### Screenshots Content Plan
1. Hero shot — game mode selection screen
2. Basketball H2H gameplay
3. Exercise demo with 3D model
4. Karate combat mode
5. Performance analytics dashboard
6. Multiplayer matchmaking

### App Preview Videos (Optional)
- [ ] 30-second gameplay video showing streaming quality
- [ ] Format: H.264, 30fps, 1080p or higher

---

## Technical Requirements

### Build & Archive
```bash
# On macOS with Xcode 15+
cd ios/FinalEvolutionLab

# Clean and archive
xcodebuild clean archive \
  -workspace FinalEvolutionLab.xcworkspace \
  -scheme FinalEvolutionLab \
  -archivePath build/FinalEvolutionLab.xcarchive \
  -destination 'generic/platform=iOS'

# Export IPA for App Store
xcodebuild -exportArchive \
  -archivePath build/FinalEvolutionLab.xcarchive \
  -exportPath build/AppStore \
  -exportOptionsPlist ExportOptions_AppStore.plist
```

### Upload to App Store Connect
```bash
# Using xcrun
xcrun altool --upload-app \
  -f build/AppStore/FinalEvolutionLab.ipa \
  -t ios \
  -u "apple-id@example.com" \
  -p "app-specific-password"

# Or use Transporter app
```

---

## Review Preparation

### Demo Account
- [ ] Provide test account credentials if app requires login
- [ ] Ensure streaming server is running during review period
- [ ] Note: Apple reviewers test on WiFi in Cupertino, CA

### Review Notes
```
This app streams real-time 3D game content from cloud GPU servers.
Requires internet connection (WiFi or 5G recommended).
Streaming server: wss://stream.finalevolutiongroup.com
No login required for basic features.
```

### Common Rejection Reasons to Avoid
- [ ] App must function without crashing
- [ ] All links must work (App Store, privacy policy, terms)
- [ ] Placeholder content must be removed
- [ ] In-app purchases must use StoreKit (if applicable)
- [ ] HealthKit must only access relevant data
- [ ] Camera/microphone permissions must be justified

---

## Post-Submission
- [ ] Monitor App Store Connect for review status
- [ ] Typical review time: 24-48 hours
- [ ] Prepare for potential reviewer questions
- [ ] Have streaming infrastructure running 24/7 during review
- [ ] Set up phased release (10% → 25% → 50% → 100%)
