#!/bin/bash

# setup.sh: Script to set up the Traefik and Cloudflare Tunnel environment.
# - Checks for existing items (e.g., .env, proxy network, directories, acme.json).
# - Copies .env.example to .env if .env doesn't exist (or overwrites if user confirms).
# - Prompts for user inputs and updates .env.
# - Creates proxy Docker network if it doesn't exist.
# - Creates config/ and logs/ directories if needed.
# - Creates and secures acme.json if needed.
# - Requires: docker, htpasswd (from apache2-utils or similar), sed.

set -e  # Exit on errors

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists docker; then
  echo "Error: Docker is not installed. Please install it first."
  exit 1
fi
if ! command_exists docker-compose && ! command_exists docker; then  # docker compose v2 is under docker
  echo "Error: docker-compose is not installed. Please install it first."
  exit 1
fi
if ! command_exists htpasswd; then
  echo "Error: htpasswd is not installed. Install apache2-utils (e.g., sudo apt install apache2-utils)."
  exit 1
fi
if ! command_exists sed; then
  echo "Error: sed is not installed."
  exit 1
fi

# Check and handle .env
if [ -f .env ]; then
  read -p ".env already exists. Overwrite with .env.example and new values? (y/n): " overwrite
  if [[ "$overwrite" != "y" ]]; then
    echo "Skipping .env setup. Existing file preserved."
  else
    cp .env.example .env
    echo ".env overwritten from .env.example."
  fi
else
  if [ ! -f .env.example ]; then
    echo "Error: .env.example not found. Please create it first."
    exit 1
  fi
  cp .env.example .env
  echo ".env created from .env.example."
fi

# Prompt for values and update .env (only if we have .env)
if [ -f .env ]; then
  echo "Enter values for .env (press Enter to keep defaults where applicable):"

  # DOMAIN
  read -p "DOMAIN (default: jsamo.com): " domain
  domain=${domain:-jsamo.com}
  sed -i "s/^DOMAIN=.*/DOMAIN=$domain/" .env

  # EMAIL
  read -p "EMAIL (for Let's Encrypt notifications): " email
  if [ -n "$email" ]; then
    sed -i "s/^EMAIL=.*/EMAIL=$email/" .env
  fi

  # CLOUDFLARE_EMAIL
  read -p "CLOUDFLARE_EMAIL (for DNS challenge): " cf_email
  if [ -n "$cf_email" ]; then
    sed -i "s/^CLOUDFLARE_EMAIL=.*/CLOUDFLARE_EMAIL=$cf_email/" .env
  fi

  # CLOUDFLARE_DNS_API_TOKEN
  read -p "CLOUDFLARE_DNS_API_TOKEN (Zone:DNS:Edit permissions): " cf_token
  if [ -n "$cf_token" ]; then
    sed -i "s/^CLOUDFLARE_DNS_API_TOKEN=.*/CLOUDFLARE_DNS_API_TOKEN=$cf_token/" .env
  fi

  # TRAEFIK_USER
  read -p "TRAEFIK_USER (default: admin): " traefik_user
  traefik_user=${traefik_user:-admin}
  sed -i "s/^TRAEFIK_USER=.*/TRAEFIK_USER=$traefik_user/" .env

  # TRAEFIK_DASHBOARD_CREDENTIALS (generate hashed version)
  read -s -p "TRAEFIK_DASHBOARD_PASSWORD (for basic auth; will be hashed): " traefik_pass
  echo
  if [ -n "$traefik_pass" ]; then
    hashed=$(htpasswd -nb "$traefik_user" "$traefik_pass")
    sed -i "s/^TRAEFIK_DASHBOARD_CREDENTIALS=.*/TRAEFIK_DASHBOARD_CREDENTIALS=$hashed/" .env
    echo "Hashed credentials generated and set."
  fi

  # TUNNEL_TOKEN
  read -p "TUNNEL_TOKEN (Cloudflare Tunnel token): " tunnel_token
  if [ -n "$tunnel_token" ]; then
    sed -i "s/^TUNNEL_TOKEN=.*/TUNNEL_TOKEN=$tunnel_token/" .env
  fi

  echo ".env updated successfully."
fi

# Create directories if they don't exist
mkdir -p config logs
echo "Directories config/ and logs/ ensured."

# Create acme.json if it doesn't exist and secure it
if [ ! -f config/acme.json ]; then
  touch config/acme.json
  chmod 600 config/acme.json
  echo "config/acme.json created and secured (chmod 600)."
else
  echo "config/acme.json already exists; skipping creation."
fi

# Create proxy network if it doesn't exist
if ! docker network ls | grep -q "proxy"; then
  docker network create proxy
  echo "Docker network 'proxy' created."
else
  echo "Docker network 'proxy' already exists; skipping creation."
fi

echo "Setup complete! Review .env, then run 'docker compose up -d' to start services."
echo "Ensure docker-compose.yml, config/traefik.yml, and config/services.yml are in place."