# qBittorrent + Gluetun

This stack keeps `Transmission` intact and adds an opt-in `qBittorrent + Gluetun` path for testing.

Services:

- `gluetun`: WireGuard VPN sidecar on `media-net`
- `qbittorrent`: shares the `gluetun` network namespace with `network_mode: "service:gluetun"`

Why it is wired this way:

- `Transmission` remains untouched.
- `qBittorrent` traffic is forced through the VPN container.
- The qBittorrent Web UI is exposed only on localhost by default.
- The profile keeps the new stack disabled until you explicitly start it.

Environment variables to fill in:

- `GLUETUN_WIREGUARD_PRIVATE_KEY`
- `GLUETUN_WIREGUARD_ADDRESSES`
- `GLUETUN_SERVER_COUNTRIES`
- `QBITTORRENT_WEBUI_PORT`
- `QBITTORRENT_TORRENTING_PORT`

Start it:

```bash
docker compose --profile vpn-qbit up -d gluetun qbittorrent
```

Open the Web UI:

```text
http://127.0.0.1:18080
```

Notes:

- On first startup, the LinuxServer qBittorrent image prints a temporary admin password to the container log.
- From Sonarr/Radarr inside the same compose network, use host `gluetun` and port `8080` if you want to add qBittorrent as a second download client.
- This improves the VPN architecture, but NordVPN still does not provide port forwarding, so torrent performance still has that provider-side ceiling.
