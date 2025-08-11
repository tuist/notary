# Release Process

## Overview

Notary uses automated daily releases following the format `vYEAR.MONTH.DAY` (e.g., `v2024.12.11`). Releases are created automatically when there are new commits since the last release.

## Automatic Daily Releases

- **Schedule**: Runs daily at 00:00 UTC
- **Condition**: Only creates a release if there are new commits since the last tag
- **Version**: Automatically uses the current date in `vYEAR.MONTH.DAY` format
- **Process**: Fully automated - builds, packages, signs, and publishes releases

## GitHub Secrets (Optional)

Signing is optional but recommended. If you want to sign your releases, configure these secrets in your GitHub repository:

### GPG Signing (Optional - for .asc files)
- **`NOTARY_GPG_KEY`**: Your GPG private key for signing checksums
  ```bash
  # Export your GPG private key
  gpg --armor --export-secret-keys YOUR_KEY_ID > private.key
  # Copy the contents to GitHub secret
  ```
- **`NOTARY_GPG_KEY_ID`**: The GPG key ID (e.g., `8B81C9D17413A06D`)
  ```bash
  # Find your key ID
  gpg --list-secret-keys --keyid-format=long
  ```

### Minisign (Optional - for .minisig files)
- **`NOTARY_MINISIGN_KEY`**: Your minisign secret key
  ```bash
  # Generate a minisign key pair if you don't have one
  minisign -G -p minisign.pub -s minisign.key
  # Copy the contents of minisign.key to GitHub secret
  ```
- **`NOTARY_MINISIGN_PUB`**: Your minisign public key
  ```bash
  # Copy the contents of minisign.pub to GitHub secret
  ```

## Release Workflow

### Automatic Daily Release

The release workflow runs automatically every day at 00:00 UTC and will:
1. Check if there are new commits since the last release
2. If changes exist, create a new release with today's date
3. Build binaries for all platforms
4. Create compressed archives (.tar.gz, .tar.xz, .tar.zst, .zip)
5. Generate SHA256 and SHA512 checksums
6. Sign checksums with GPG and minisign
7. Create and push a Git tag
8. Create a GitHub release with all artifacts

No manual intervention is required for regular releases.

### Manual Release

You can also trigger a release manually from GitHub Actions:

1. Go to Actions → Release workflow
2. Click "Run workflow"
3. Optionally:
   - Specify a custom version (defaults to current date)
   - Check "Force release" to create a release even if no changes exist
4. The workflow will check for changes and create a release if needed

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