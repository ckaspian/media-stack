Media Stack - Modernized Docker Compose Setup
A fully automated media server stack with VPN-protected downloading, automated content management, and secure remote streaming capabilities.

🎯 Key Improvements Made
1. Organization & Structure
Clear sectioning with visual separators and logical grouping of services.

Comprehensive comments and consistent naming conventions (kebab-case for containers).

2. Reduced Redundancy with YAML Anchors
Common configurations like user IDs, timezone, and restart policies are defined once and reused everywhere, making the stack easier to maintain.

3. Enhanced Features
✅ Health Checks: Automatically monitor if services are running correctly.

✅ Resource Limits: Prevent runaway containers from crashing your server.

✅ Network Isolation: Services are separated into logical networks for enhanced security.

✅ Dependency Management: Ensures services like download clients start only after their VPN is ready.

✅ Labels for Integrations: Ready for optional tools like Watchtower (auto-updates) and Traefik (reverse proxy).

4. Improved Scripting & Configuration
The slskd wrapper script now includes better error handling, logging, and signal trapping for clean shutdowns.

The .env file is logically grouped with detailed documentation for all required and optional settings.

📦 Stack Components
| Service | Purpose | Port | VPN Protected | Version |
| qBittorrent | Torrent Client | 8080 | ✅ | latest |
| slskd | Soulseek Client | 8585 | ✅ | latest |
| Sonarr | TV Show Management | 8181 | ❌ | latest |
| Radarr | Movie Management | 8282 | ❌ | latest |
| Lidarr | Music Management | 8383 | ❌ | 2.14.1-nightly |
| Readarr | Book Management | 8484 | ❌ | 0.4.19-nightly |
| Prowlarr | Indexer Management | 9696 | ❌ | 2.1.0-develop |
| Picard | Music Tagger | 8586 | ❌ | 2.13.3 |
| Navidrome | Music Streaming | 8686 | ❌ | latest |
| Cloudflared | Remote Access Tunnel | N/A | ❌ | latest |

🚀 Quick Start
1. Prerequisites
# Install Docker and Docker Compose
curl -fsSL [https://get.docker.com](https://get.docker.com) | sh
sudo usermod -aG docker $USER

# Log out and log back in for the group change to take effect.
# Then, get your user/group IDs for the .env file.
id


2. Configuration
# Clone or create the stack directory
mkdir -p ~/media-stack
cd ~/media-stack

# Create the required directory structure
mkdir -p scripts data/{config,downloads,media/{tv,movies,music,books}}

# Download/copy the following files into ~/media-stack:
# - docker-compose.yml
# - example.env
# - scripts/slskd-wrapper.sh

# Make the wrapper script executable
chmod +x scripts/slskd-wrapper.sh

# Create your .env file from the example
cp example.env .env

# Edit the .env file with your specific values
nano .env
# IMPORTANT: Update DATA_ROOT, PUID, PGID, and your VPN keys.
# OPTIONAL: Update the CLOUDFLARE_TUNNEL_TOKEN if you want remote access.


3. VPN Setup
Get a WireGuard configuration from your VPN provider (e.g., ProtonVPN, Mullvad).

Extract the private key for each VPN connection you need.

Paste the keys into the .env file:

TORRENT_WIREGUARD_PRIVATE_KEY="your_key_for_torrents_goes_here"
SLSKD_WIREGUARD_PRIVATE_KEY="your_key_for_slskd_goes_here"


4. Launch the Stack
# Start all services in the background
docker compose up -d

# Check the status of all containers
docker compose ps

# View the logs of all running services
docker compose logs -f

# To view logs for a specific service (e.g., vpn-torrents)
docker compose logs -f vpn-torrents

# Stop and remove all services
docker compose down


🔧 Service Configuration
Connect Sonarr to qBittorrent
Open Sonarr: http://localhost:8181

Go to Settings → Download Clients → Add (+) → qBittorrent.

Host: vpn-torrents (this is the Docker service name, not localhost).

Port: 8080.

Add Indexers via Prowlarr
Open Prowlarr: http://localhost:9696

Add your indexers.

Go to Settings → Apps → Add Application (+) and select Sonarr.

Prowlarr Server: http://prowlarr:9696

Sonarr Server: http://sonarr:8989 (use the internal container port).

Repeat for Radarr, Lidarr, and Readarr using their respective service names and internal ports.

Configure Media Paths
All *arr applications and Picard should be configured with these container paths:

Root/Downloads Path: /downloads

Media Paths: /tv, /movies, /music, /books respectively.

🛡️ Security & Remote Access
Network Isolation
The stack uses multiple isolated Docker networks to ensure services can only communicate with what they need to. For example, the vpn_torrents network isolates qBittorrent's traffic, while the media_network is used for internal communication between the *arr apps.

Cloudflare Tunnel for Secure Remote Access
Instead of opening ports on your router, you can use the built-in Cloudflare Tunnel to securely expose services like Navidrome.

Get a tunnel token from the Cloudflare Zero Trust dashboard.

Add the token to CLOUDFLARE_TUNNEL_TOKEN in your .env file.

In the Cloudflare dashboard, point your desired hostname (e.g., music.yourdomain.com) to the service http://navidrome:4533.

Start the stack. The cloudflared-navidrome service will automatically connect to Cloudflare.

📊 Monitoring & Maintenance
Health Checks
All critical services include a health check to verify they are operational. You can see the status by running docker compose ps. A status of healthy indicates the service is running correctly.

Backup Strategy
It's crucial to back up your configuration volumes. A simple strategy is to stop the stack and create a compressed archive of the data/config directory.

# Example backup script
#!/bin/bash
BACKUP_DIR="/path/to/backups/media-stack-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
cd ~/media-stack

echo "Stopping services..."
docker compose down

echo "Backing up configuration..."
tar -czf "$BACKUP_DIR/configs.tar.gz" data/config/

echo "Restarting services..."
docker compose up -d


🔍 Troubleshooting
Port Conflicts
If a port is already in use on your host, you'll see an error on startup.

# Find out which process is using a port (e.g., 8080)
sudo lsof -i :8080

# Change the conflicting port in your .env file
QBITTORRENT_WEBUI_PORT=8081 # Change to an unused port


After changing the port, restart the stack with docker compose up -d.

Permission Issues
If you see "Permission Denied" errors in the logs, it's likely a file ownership issue inside the containers.

# The stack includes a one-off service to fix this.
docker compose run --rm init-permissions

# Alternatively, fix it manually from your host
sudo chown -R 1000:1000 data/ # Replace 1000:1000 with your PUID:PGID


📚 Resources
Docker Compose Documentation

Gluetun Wiki

TRaSH Guides - Best practices for *arr setup.
