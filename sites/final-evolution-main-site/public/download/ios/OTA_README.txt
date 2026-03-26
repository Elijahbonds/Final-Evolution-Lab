Over-the-air iOS install (finalevolutiongroup.com)
==================================================

1) Build & export FinalEvolutionLab.ipa
   - Xcode: Archive → Distribute App → Ad Hoc or Enterprise (not App Store).
   - Or run Scripts/package_ios_distribution_ipa.sh on a Mac with UE 5.7 + signing set up.

2) Upload the IPA (large file — do not commit to git)
   - Supabase bucket: sovereign-assets
   - Object path: ios/FinalEvolutionLab.ipa
   - Must be public-read so the URL in manifest.plist returns 200.

3) Keep manifest.plist in sync
   - bundle-identifier: must match the signed .ipa (see Config/FEL_IOS_BUNDLE_ID.txt).
   - bundle-version: CFBundleVersion from the built app (e.g. 1.0.0).

4) Test on iPhone
   - Open Safari: https://finalevolutiongroup.com/download/ios
   - Accept the “Install Sovereign Lab?” prompt; trust the developer profile in Settings if needed.

5) Custom domain on Netlify
   - Point finalevolutiongroup.com DNS to Netlify; deploy final-evolution-main-site.
