# qBittorrent + Gluetun

This repository keeps the existing `Transmission-OpenVPN` service and adds an independent, opt-in `qBittorrent + Gluetun` stack for testing and gradual migration.

## Why this stack

Gluetun is kept separate from qBittorrent so VPN transport, firewalling and application lifecycle are isolated. qBittorrent uses `network_mode: "service:gluetun"`, which makes it share Gluetun's network namespace. If the VPN path is unavailable, qBittorrent has no separate Docker network path to bypass it.

Gluetun supports NordVPN directly with both OpenVPN and WireGuard. OpenVPN is the recommended first setup here because it reuses the same NordVPN service credentials already used by Transmission.

All-in-one VPN/qBittorrent images were considered as well. The separate Gluetun model is kept because NordVPN is a native provider, VPN lifecycle/firewalling stay independent from qBittorrent, and the torrent client can be replaced without changing the VPN layer.

## Configuration

Fill these values in `.env`:

- `GLUETUN_VPN_TYPE=openvpn` for the initial setup
- `GLUETUN_SERVER_COUNTRIES=Austria` or another comma-separated country list
- `QBITTORRENT_WEBUI_PORT=18080`
- `QBITTORRENT_TORRENTING_PORT=6881`

For OpenVPN, Gluetun uses `NORDVPN_USER` and `NORDVPN_PASS`. These must be NordVPN service credentials, not the normal account email/password.

For NordVPN WireGuard, set:

```dotenv
GLUETUN_VPN_TYPE=wireguard
GLUETUN_WIREGUARD_PRIVATE_KEY=your_real_nordvpn_wireguard_private_key
```

NordVPN's native Gluetun integration requires the WireGuard private key; a separate `WIREGUARD_ADDRESSES` value is not required for this provider.

The Compose file also sets `UPDATER_PERIOD=480h`, which lets Gluetun periodically refresh its internal VPN server list without checking excessively often.

## Start the optional stack

```bash
docker compose --profile vpn-qbit up -d gluetun qbittorrent
```

Check status:

```bash
docker compose --profile vpn-qbit ps
docker logs gluetun
docker logs qbittorrent
```

The WebUI is deliberately published only on localhost:

```text
http://127.0.0.1:18080
```

On first startup the LinuxServer qBittorrent image prints a temporary password for the `admin` user in its container log. Change the credentials in qBittorrent after logging in.

## Sonarr / Radarr integration

Because Gluetun is attached to `media-net`, containers on that network can reach qBittorrent through Gluetun's container address. Add qBittorrent as a second download client using:

```text
Host: gluetun
Port: 8080
```

No Docker host-port publication is needed for this container-to-container path.

Keep Transmission configured until the qBittorrent path has been tested successfully. This lets both clients coexist without changing the current production download path.

## Port-forwarding note

NordVPN does not provide inbound port forwarding. Therefore the Compose file intentionally does **not** publish qBittorrent's torrent TCP/UDP port on the Docker host and does not set `FIREWALL_VPN_INPUT_PORTS` for it. Publishing a Docker host port would not create an inbound forwarded port on NordVPN's public VPN address.

The `TORRENTING_PORT` setting is still retained so qBittorrent has a deterministic internal listen port.

## Update policy

WUD performs the normal stack's automatic image updates on Sundays around 12:00 Europe/Vienna time.

The `gluetun` and `qbittorrent` containers are deliberately excluded from WUD's automatic Docker trigger because qBittorrent shares Gluetun's network namespace. Recreating only Gluetun could leave the already-running qBittorrent attached to the old namespace.

WUD still watches these containers and may send Telegram update notifications. Upgrade the pair together:

```bash
docker compose --profile vpn-qbit pull gluetun qbittorrent
docker compose --profile vpn-qbit up -d gluetun qbittorrent
```

Afterwards verify both containers and confirm qBittorrent still reaches the Internet through the VPN.
