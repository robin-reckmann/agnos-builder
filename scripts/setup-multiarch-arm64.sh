#!/usr/bin/env bash
set -e

# Only do work on x86_64 (amd64) hosts
if [ "$(uname -m)" != "x86_64" ]; then
  exit 0
fi

# Enable arm64 as a foreign architecture
dpkg --add-architecture arm64

# Restrict the stock Deb822 file to amd64 only
sed -i '/^Components:/a Architectures: amd64' /etc/apt/sources.list.d/ubuntu.sources

# Add a Deb822 file for arm64 via ports
cat > /etc/apt/sources.list.d/ubuntu-arm64.sources <<'EOF'
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports
Suites: noble noble-updates noble-backports noble-security
Components: main restricted universe multiverse
Architectures: arm64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF