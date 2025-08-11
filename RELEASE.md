# Release Process

## Overview

Notary uses automated releases triggered by Git tags following the format `vYEAR.MONTH.DAY` (e.g., `v2024.12.11`).

## Required GitHub Secrets

To enable the full release process with signed artifacts, configure the following secrets in your GitHub repository:

### GPG Signing (Required for .asc files)
- **`NOTARY_GPG_KEY`**: Your GPG private key for signing checksums
  ```bash
  # Export your GPG private key
  gpg --armor --export-secret-keys YOUR_KEY_ID > private.key
  # Copy the contents to GitHub secret
  ```
- **`GPG_KEY_ID`**: The GPG key ID (e.g., `8B81C9D17413A06D`)
  ```bash
  # Find your key ID
  gpg --list-secret-keys --keyid-format=long
  ```

### Minisign (Required for .minisig files)
- **`MINISIGN_KEY`**: Your minisign secret key
  ```bash
  # Generate a minisign key pair if you don't have one
  minisign -G -p minisign.pub -s minisign.key
  # Copy the contents of minisign.key to GitHub secret
  ```
- **`MINISIGN_PUB`**: Your minisign public key
  ```bash
  # Copy the contents of minisign.pub to GitHub secret
  ```

## Release Workflow

### Automatic Release (Recommended)

1. Create and push a version tag:
   ```bash
   VERSION="v$(date +%Y.%m.%d)"
   git tag -s -m "Release $VERSION" "$VERSION"
   git push origin "$VERSION"
   ```

2. The GitHub Actions workflow will automatically:
   - Build binaries for all platforms
   - Create compressed archives (.tar.gz, .tar.xz, .tar.zst, .zip)
   - Generate SHA256 and SHA512 checksums
   - Sign checksums with GPG and minisign
   - Create a GitHub release with all artifacts

### Manual Release

You can also trigger a release manually from GitHub Actions:

1. Go to Actions → Release workflow
2. Click "Run workflow"
3. Optionally specify a version (defaults to current date)
4. The workflow will create and tag the release

## Release Artifacts

Each release includes:

### Binary Archives
- `notary-vYEAR.MONTH.DAY-linux-amd64.tar.{gz,xz,zst}`
- `notary-vYEAR.MONTH.DAY-linux-arm64.tar.{gz,xz,zst}`
- `notary-vYEAR.MONTH.DAY-linux-armv7.tar.{gz,xz,zst}`
- `notary-vYEAR.MONTH.DAY-darwin-amd64.tar.{gz,xz,zst}`
- `notary-vYEAR.MONTH.DAY-darwin-arm64.tar.{gz,xz,zst}`
- `notary-vYEAR.MONTH.DAY-windows-amd64.zip`
- `notary-vYEAR.MONTH.DAY-windows-arm64.zip`

### Checksums
- `SHASUMS256.txt`: SHA256 checksums for all files
- `SHASUMS512.txt`: SHA512 checksums for all files

### Signatures
- `SHASUMS256.asc`: GPG signature of SHA256 checksums
- `SHASUMS512.asc`: GPG signature of SHA512 checksums
- `SHASUMS256.minisig`: Minisign signature of SHA256 checksums
- `SHASUMS512.minisig`: Minisign signature of SHA512 checksums

## Verifying Releases

### Verify with GPG

```bash
# Import the public key (one time)
gpg --recv-keys YOUR_KEY_ID

# Verify checksums
gpg --verify SHASUMS256.asc SHASUMS256.txt
gpg --verify SHASUMS512.asc SHASUMS512.txt

# Verify file integrity
sha256sum -c SHASUMS256.txt
sha512sum -c SHASUMS512.txt
```

### Verify with Minisign

```bash
# Save the public key (one time)
echo "YOUR_PUBLIC_KEY" > minisign.pub

# Verify checksums
minisign -Vm SHASUMS256.txt -p minisign.pub
minisign -Vm SHASUMS512.txt -p minisign.pub

# Verify file integrity
sha256sum -c SHASUMS256.txt
sha512sum -c SHASUMS512.txt
```

## Local Testing

Test the release process locally:

```bash
# Build for current platform
mise run build-release

# Package the binary
mise run package

# Test the full release process (without uploading)
VERSION=v2024.12.11 DRY_RUN=1 mise run release
```

## Changelog

The release process automatically generates a changelog using git-cliff based on conventional commits. To generate a changelog manually:

```bash
git-cliff --latest --strip header -o CHANGELOG.md
```