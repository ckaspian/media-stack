# Migration Guide: Old Stack → Modernized Stack

## 🔄 Quick Migration Checklist

- [ ] Backup your current configuration
- [ ] Stop the old stack
- [ ] Update file paths in `.env`
- [ ] Copy wrapper script to new location
- [ ] Test with one service first
- [ ] Migrate all services
- [ ] Verify everything works

## 📋 What Changed?

### Container Names
| Old Name | New Name | Reason |
|----------|----------|--------|
| `gluetun-torrents` | `vpn-torrents` | Clearer purpose |
| `gluetun-slskd` | `vpn-slskd` | Clearer purpose |
| `vpn-sync-init` | `init-permissions` | More descriptive |

### Directory Structure
```bash
# Old structure
./data/
├── config/
│   ├── gluetun-torrents/    # Changed
│   └── gluetun-slskd/        # Changed
└── media/

# New structure  
./data/
├── config/
│   ├── vpn-torrents/         # Renamed
│   ├── vpn-slskd/            # Renamed
│   └── prowlarr/             # New addition
└── media/
    ├── downloads/            # Moved under media
    ├── tv/                   # Organized by type
    ├── movies/
    ├── music/
    └── books/
```

### Environment Variables
```bash
# Old
LOCATION=/mnt/hdd/

# New (more descriptive)
DATA_ROOT=/mnt/hdd

# New additions
GLUETUN_TORRENTS_API_PORT=8000
GLUETUN_SLSKD_API_PORT=8001
PROWLARR_PORT=9696

# Version specifications (with defaults from docker-compose.yml)
READARR_VERSION=0.4.19-nightly  # default: nightly
LIDARR_VERSION=2.14.1-nightly   # default: nightly
PROWLARR_VERSION=2.1.0-develop  # default: develop
PICARD_VERSION=2.13.3           # default: 2.13.3
```

## 🚀 Step-by-Step Migration

### Step 1: Backup Current Setup
```bash
# Create backup directory
mkdir -p ~/media-stack-backup

# Stop current stack
docker compose down

# Backup configs (adjust paths as needed)
cp -r ./data/config ~/media-stack-backup/
cp docker-compose.yml ~/media-stack-backup/
cp .env ~/media-stack-backup/
cp slskd-wrapper.sh ~/media-stack-backup/

# List current volumes
docker volume ls | grep -E "(gluetun|qbit|sonarr|radarr|lidarr|readarr|navidrome|slskd)"
```

### Step 2: Prepare New Structure
```bash
# Create new directory structure
mkdir -p data/media/{downloads,tv,movies,music,books}
mkdir -p scripts

# Copy wrapper script
cp slskd-wrapper.sh scripts/
chmod +x scripts/slskd-wrapper.sh
```

### Step 3: Rename Existing Config Directories
```bash
# Rename Gluetun configs to match new names
cd data/config
mv gluetun-torrents vpn-torrents
mv gluetun-slskd vpn-slskd
cd ../..
```

### Step 4: Update Configuration Files

#### Update `.env`:
```bash
# Change LOCATION to DATA_ROOT
sed -i 's/LOCATION=/DATA_ROOT=/g' .env

# Or manually edit
nano .env
```

#### Key changes to make:
1. `LOCATION` → `DATA_ROOT`
2. Add new port variables if needed
3. Verify VPN keys are correct

### Step 5: Test Migration with One Service
```bash
# Start just the VPN and qBittorrent first
docker compose up -d vpn-torrents qbittorrent

# Check logs
docker compose logs -f vpn-torrents

# Verify web UI works
curl http://localhost:8080

# If successful, continue...
```

### Step 6: Start Remaining Services
```bash
# Bring up the rest
docker compose up -d

# Monitor logs
docker compose logs -f

# Check all services are healthy
docker compose ps
```

## 🔍 Verification Steps

### 1. Check VPN Connectivity
```bash
# Torrent VPN
docker exec vpn-torrents curl -s https://api.ipify.org
# Should show VPN IP, not your real IP

# Slskd VPN
docker exec vpn-slskd curl -s https://api.ipify.org
```

### 2. Verify Port Forwarding
```bash
# Check if port files exist
docker exec vpn-torrents cat /tmp/qbit_port
docker exec vpn-slskd cat /vpn-sync/forwarded_port
```

### 3. Test Web UIs
Open in browser:
- qBittorrent: http://localhost:8080
- Sonarr: http://localhost:8181
- Radarr: http://localhost:8282
- Lidarr: http://localhost:8383
- Readarr: http://localhost:8484
- Prowlarr: http://localhost:9696
- Navidrome: http://localhost:8686
- Slskd: http://localhost:8585
- Picard: http://localhost:8586

### 4. Check Inter-Service Communication
In Sonarr/Radarr settings:
- Download client host should be `vpn-torrents` (not `localhost`)
- Port: 8080

## ⚠️ Common Issues & Solutions

### Issue: "Container name already in use"
```bash
# Remove old containers
docker rm -f gluetun-torrents gluetun-slskd vpn-sync-init

# Or remove all stopped containers
docker container prune
```

### Issue: "Volume already exists"
```bash
# If you want to keep data, no action needed
# If you want fresh start:
docker volume rm vpn-sync
```

### Issue: Permission Denied
```bash
# Run the init container
docker compose run --rm init-permissions

# Or fix manually
sudo chown -R $(id -u):$(id -g) data/
```

### Issue: Port Already in Use
```bash
# Find what's using the port
sudo lsof -i :8080

# Change port in .env
QBITTORRENT_WEBUI_PORT=8081
```

## 📦 Rollback Plan

If something goes wrong:

```bash
# Stop new stack
docker compose down

# Restore old files
cp ~/media-stack-backup/docker-compose.yml .
cp ~/media-stack-backup/.env .
cp ~/media-stack-backup/slskd-wrapper.sh .

# Restore config directory names
cd data/config
mv vpn-torrents gluetun-torrents
mv vpn-slskd gluetun-slskd
cd ../..

# Start old stack
docker compose up -d
```

## 🎯 Post-Migration Optimizations

### 1. Enable Health Monitoring
```bash
# Check health status
watch -n 5 'docker compose ps'
```

### 2. Set Up Log Rotation
Add to each service in docker-compose.yml:
```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

### 3. Configure Prowlarr (New Addition)
1. Open http://localhost:9696
2. Add your indexers
3. Connect to all *arr apps:
   - Host: `sonarr` (use Docker service names)
   - Port: 8989 (internal port)

### 4. Update Download Client Settings
In each *arr app, update download client:
- Old host: `localhost` or `gluetun-torrents`
- New host: `vpn-torrents`

## ✅ Success Indicators

You know the migration is successful when:
- All containers show "healthy" status
- VPN containers show forwarded ports
- Web UIs are accessible
- *arr apps can communicate with download clients
- Downloads start working
- Media is accessible in Navidrome/Jellyfin

## 📝 Notes

- The modernized stack is backward compatible with your data
- Config files remain unchanged (except for network names)
- Media files don't need to be moved
- Database files are preserved

---
*Need help? Check the README.md for detailed documentation*
