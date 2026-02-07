#!/bin/bash
set -e

# Setup script for Debian homeserver
# Installs: git, docker, docker compose, nvim, python3

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (sudo ./setup.sh)"
  exit 1
fi

apt-get update

# Git
if command -v git &>/dev/null; then
  echo "git is already installed: $(git --version)"
else
  echo "Installing git..."
  apt-get install -y git
fi

# Python3
if command -v python3 &>/dev/null; then
  echo "python3 is already installed: $(python3 --version)"
else
  echo "Installing python3..."
  apt-get install -y python3
fi

# Neovim
if command -v nvim &>/dev/null; then
  echo "nvim is already installed: $(nvim --version | head -1)"
else
  echo "Installing neovim..."
  apt-get install -y neovim
fi

# Docker
if command -v docker &>/dev/null; then
  echo "docker is already installed: $(docker --version)"
else
  echo "Installing docker..."
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Docker Compose (comes as a plugin with the above, verify it works)
if docker compose version &>/dev/null; then
  echo "docker compose is available: $(docker compose version)"
else
  echo "ERROR: docker compose plugin not found. Try reinstalling docker."
  exit 1
fi

echo ""
echo "All packages installed successfully."
