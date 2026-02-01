# Forks Release Guide

## Quick Start (Recommended)

### Option 1: Push Tag (Automated via GitHub Actions)
```bash
# Push a tag to trigger automatic release
git tag v0.6.0
git push origin v0.6.0
```

GitHub Actions will automatically:
1. Build the app
2. Create DMG and ZIP
3. Sign appcast with Sparkle
4. Create GitHub Release
5. Commit version bump back to main

### Option 2: Use Quick Release Script
```bash
./scripts/quick-release.sh 0.6.0           # Release 0.6.0
./scripts/quick-release.sh 0.6.0-beta-1    # Release beta
./scripts/quick-release.sh patch           # Bump patch and release
```

### Option 3: Manual Trigger from GitHub UI
1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Enter version (e.g., `0.6.0`)
4. Click **Run workflow**

---

## Prerequisites (One-time Setup)

### 1. Add GitHub Secret
Go to **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Name | Value |
|------|-------|
| `SPARKLE_PRIVATE_KEY` | Your Sparkle EdDSA private key |

To export your Sparkle private key:
```bash
./.sparkle/bin/generate_keys -x /tmp/sparkle_key.txt
cat /tmp/sparkle_key.txt
rm /tmp/sparkle_key.txt
```

### 2. Install Local Dependencies (for local release)
```bash
brew install create-dmg
gh auth login
```

### 3. Generate Sparkle Keys (if not already done)
```bash
./.sparkle/bin/generate_keys
# Copy public key to forks/Info.plist → SUPublicEDKey
```

---

## Release Methods

### GitHub Actions (Recommended)

**Trigger by tag push:**
```bash
git tag v0.6.0
git push origin v0.6.0
```

**Trigger manually:**
- Go to Actions → Release → Run workflow

**What it does:**
1. Validates tag format
2. Bumps version in project.pbxproj
3. Builds with Xcode 16
4. Creates ZIP and DMG packages
5. Signs appcast with Sparkle
6. Creates GitHub Release with assets
7. Commits version changes back to main

### Local Release (Fallback)

```bash
./scripts/bump-version.sh patch   # 0.5.0 → 0.5.1
./scripts/bump-version.sh minor   # 0.5.0 → 0.6.0
./scripts/bump-version.sh major   # 0.5.0 → 1.0.0
./scripts/bump-version.sh 1.2.3   # Set specific version
```

---

## Beta/Pre-release

```bash
./scripts/quick-release.sh 1.0.0-beta-1    # First beta
./scripts/quick-release.sh 1.0.0-beta-2    # Second beta
```

Beta releases:
- Are marked as pre-release on GitHub
- Include `<sparkle:channel>beta</sparkle:channel>` in appcast.xml
- Only visible to users who opt-in via Settings → Updates → Update Channel → Beta

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/quick-release.sh` | Interactive release helper (tag + push) |
| `scripts/bump-version.sh` | Update version in project |
| `scripts/build.sh` | Build release archive |
| `scripts/package.sh` | Create ZIP and DMG |
| `scripts/generate-appcast-ci.sh` | Generate appcast (CI, uses env var) |

---

## Version Naming

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backward compatible
- **PATCH** (0.0.1): Bug fixes
- **BETA** (1.0.0-beta-1): Pre-release versions for testing

---

## Troubleshooting

### GitHub Actions Failed
- Check **Actions** tab for error logs
- Verify `SPARKLE_PRIVATE_KEY` secret is set correctly
- Ensure tag format is `v*` (e.g., `v0.6.0`)

### Gatekeeper Warning on First Launch
→ Expected for unsigned apps. Users can right-click → Open to bypass, or run:
```bash
xattr -cr /Applications/forks.app
```

### Version Bump Not Committed
→ Check if `[skip ci]` is working. The workflow uses this to prevent infinite loops.

---

## Release Checklist

**Before release:**
- [ ] All changes committed and pushed

**After tag push:**
- [ ] GitHub Actions workflow started
- [ ] Build succeeded
- [ ] GitHub Release created with DMG, ZIP, appcast.xml
- [ ] Version bump committed to main

**Verify:**
- [ ] Download and test the DMG
- [ ] Check auto-update works (Sparkle)
