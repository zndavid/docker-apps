# qBittorrent + Gluetun

`qBittorrent + Gluetun` is the primary torrent stack in this repository. The previous `Transmission-OpenVPN` service has been removed.

## Why this stack

Gluetun is kept separate from qBittorrent so VPN transport, firewalling and application lifecycle remain isolated. qBittorrent uses:

```yaml
network_mode: "service:gluetun"
```

This makes qBittorrent share Gluetun's network namespace. qBittorrent therefore has no separate Docker network path that could bypass the VPN tunnel.

## Configuration

The default setup uses NordVPN WireGuard. Set these values in the Portainer stack environment (or in `.env` for local Compose):

```dotenv
GLUETUN_VPN_TYPE=wireguard
GLUETUN_WIREGUARD_PRIVATE_KEY=your_real_nordvpn_wireguard_private_key
GLUETUN_SERVER_COUNTRIES=Austria
QBITTORRENT_WEBUI_PORT=18080
QBITTORRENT_TORRENTING_PORT=6881
```

NordVPN's native Gluetun integration requires the WireGuard private key. A separate `WIREGUARD_ADDRESSES` value is not required for this provider.

OpenVPN remains available as a fallback. If you deliberately set `GLUETUN_VPN_TYPE=openvpn`, also provide NordVPN service credentials through `NORDVPN_USER` and `NORDVPN_PASS`.

The Compose file sets `UPDATER_PERIOD=480h`, allowing Gluetun to refresh its VPN server list periodically.

## Start the stack

For the Git-managed deployment, follow [NAS deployment](nas-deploy.md) and use Portainer. The commands below are for a local Compose checkout; do not run a second Compose project alongside the Portainer stack.

Gluetun and qBittorrent are normal services now; no Compose profile is required:

```bash
docker compose up -d gluetun qbittorrent
```

Check status:

```bash
docker compose ps gluetun qbittorrent
docker logs --tail 100 gluetun
docker logs --tail 100 qbittorrent
```

The qBittorrent WebUI is published on the NAS at the configured port. With the default value and NAS address `192.168.178.78`:

```text
http://192.168.178.78:18080
```

On first startup the LinuxServer qBittorrent image may print a temporary password for the `admin` user in its container log. Set a permanent WebUI password after logging in; the qBittorrent config volume persists it across container recreation.

## Verify VPN egress

To verify traffic through Gluetun, run a temporary container inside Gluetun's network namespace:

```bash
docker run --rm --network=container:gluetun alpine:3.22 \
  sh -c "apk add --no-cache wget >/dev/null && wget -qO- https://ipinfo.io"
```

The returned public IP should be the VPN exit address rather than the NAS/router's normal public IP. With `SERVER_COUNTRIES=Austria`, the selected exit should normally be in Austria.

## Sonarr / Radarr integration

Because Gluetun is attached to `media-net`, Sonarr and Radarr can reach qBittorrent through the Gluetun service name. Configure qBittorrent as the download client with:

```text
Host: gluetun
Port: 18080
SSL: off
```

Use the qBittorrent WebUI username/password configured in qBittorrent. Keep distinct categories such as `sonarr` and `radarr` so the applications can track their own downloads.

Sonarr and Radarr no longer depend on a Transmission container during startup. If Gluetun or qBittorrent is temporarily unavailable, the Arr applications remain available and simply report the download client as unavailable until the VPN stack recovers.

## Storage paths

qBittorrent and Arr agree on `/data/torrents/...`; Radarr/Sonarr import into
`/data/media/...` through one shared mount. Follow
[storage migration](storage-migration.md) for existing torrent locations,
categories and library roots before enabling imports.

## Download cleanup

The previous repository script that configured Transmission-specific seeding and cleanup has been removed. Torrent seeding limits and completed-download removal should now be configured in qBittorrent and the Arr applications themselves.

This avoids keeping a second automation layer tied to a download client that is no longer part of the stack.

## Port-forwarding note

NordVPN does not provide inbound port forwarding. Therefore the Compose file intentionally does **not** publish qBittorrent's torrent TCP/UDP listen port on the Docker host and does not open a VPN input port for it.

`QBITTORRENT_TORRENTING_PORT` is retained so qBittorrent has a deterministic internal listen port.

## Update policy

WUD checks images and sends notifications on Sundays around 12:00
Europe/Vienna time; independent media container updates are manual.

The `gluetun` and `qbittorrent` containers are deliberately excluded from WUD's automatic Docker trigger because qBittorrent shares Gluetun's network namespace. Recreating only Gluetun could leave an already-running qBittorrent attached to the old namespace.

WUD can still watch these containers and send Telegram update notifications. Upgrade the pair together using the project/revision-aware maintenance
procedure in [update policy](update-policy.md#gluetun--qbittorrent-must-be-updated-together).
Afterwards verify both containers, their shared namespace and VPN egress.
