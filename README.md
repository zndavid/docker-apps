# Media stack

QNAP Docker Compose stack for Jellyfin, Seerr, Sonarr, Radarr, Prowlarr,
Bazarr and qBittorrent behind Gluetun, with Cloudflare Tunnel and WUD.
Home Assistant is managed separately with `docker-compose.homeassistant.yml`.

Configuration deploys from GitHub through **Portainer GitOps polling**. Image
checks run weekly in WUD; eligible containers are updated automatically after detection.
There is no GitHub-to-NAS SSH access, webhook, NAS Actions runner, custom image
build or repository-relative bind mount. Actions only validates configuration
and regression cases; it has no NAS or runtime-secret access.

## Before the first deployment

1. Prepare the shared data tree and application path transition using
   [storage migration](docs/storage-migration.md). Do not enable polling over
   an unmigrated stack: this Compose definition changes existing media paths.
2. Back up WUD and supply a private v9 admin password as described in
   [update policy](docs/update-policy.md).
3. Complete the ownership handover in [NAS deployment](docs/nas-deploy.md),
   including [Home Assistant's separate stack](docs/homeassistant-deploy.md).
4. Import the corrected [Radarr custom formats](docs/radarr-custom-formats.md)
   into Radarr; Compose deployment does not apply JSON profiles automatically.
5. If NAS GPU checks succeed, add the [Jellyfin GPU override](docs/jellyfin-gpu.md).
6. Verify hardlinks, seeding, playback, recovery and authentication before
   resuming automation and enabling 5-minute polling.

Use [.env.example](.env.example) as a runtime-variable template; replace its
placeholders privately in Portainer. Review changes on branches and wait for
validation before merging to `main`.

The ebook services are removed, with existing NAS book/config directories
retained. Profilarr and Cleanuparr are not included.

- [VPN setup](docs/qbittorrent-gluetun.md)
- [VPN reconnect recovery](docs/qbittorrent-vpn-recovery.md)

## Local validation

```bash
docker compose --env-file .env.example config --quiet
docker compose --env-file .env.example -f docker-compose.homeassistant.yml config --quiet
python3 .github/scripts/test-radarr-formats.py
```

The CI also validates the optional Jellyfin GPU override. These checks do not
verify the NAS filesystem, driver or real runtime credentials.
