# Certificates Directory

This directory contains Apple Developer certificates for the Final Evolution Lab iOS app.

## Files

| File | Purpose |
|------|--------|
| `FinalEvolutionLab.pem` | Development/Distribution signing certificate |
| `Final Evolution Lab.pem` | Push notification certificate |

## Usage

### Import into Keychain (on Mac)

```bash
# Import development certificate
security import FinalEvolutionLab.pem -k ~/Library/Keychains/login.keychain-db

# Import push notification certificate
security import "Final Evolution Lab.pem" -k ~/Library/Keychains/login.keychain-db
```

### Convert PEM to P12 (if needed)

```bash
openssl pkcs12 -export \
  -in FinalEvolutionLab.pem \
  -out FinalEvolutionLab.p12 \
  -password pass:your_password
```

### Automatic Signing

For development, Xcode's **Automatic Signing** is recommended:
1. Open `ios/FinalEvolutionLab.xcodeproj`
2. Select target → Signing & Capabilities
3. Enable "Automatically manage signing"
4. Select your Apple Developer team

## Security

⚠️ These files should **never** be committed to a public repository.  
Add `certs/` to `.gitignore` for public repos.
