# Container update policy

This stack intentionally does not apply unattended container updates.

## Why

Automatic replacement of running containers can turn an upstream image regression into an immediate outage. This is especially undesirable for Home Assistant, VPN networking and the media download path.

The stack therefore uses **What's up Docker (WUD)** to inspect running containers, compare their images with registry versions and expose update status through a Web UI/API. WUD is configured here as an observer only: no automatic Docker Compose update trigger is enabled.

## WUD access

The Web UI listens on the host loopback interface only:

```text
http://127.0.0.1:13000
```

The host-side port can be changed with `WUD_WEBUI_PORT`.

WUD is also attached to `media-net`, so a reverse proxy or Cloudflare Tunnel container on the same network can reach it at:

```text
http://wud:3000
```

## Normal update workflow

After reviewing an available update in WUD, update deliberately:

```bash
docker compose pull
docker compose up -d
docker compose ps
```

For the optional qBittorrent + Gluetun profile:

```bash
docker compose --profile vpn-qbit pull
docker compose --profile vpn-qbit up -d
docker compose --profile vpn-qbit ps
```

Inspect service logs after important updates, especially for:

- `homeassistant`
- `gluetun`
- `qbittorrent`
- `transmission-openvpn`
- `jellyfin`

## Why WUD instead of Watchtower or Diun

Watchtower was removed because unattended updates are not desirable for this stack.

Diun is an excellent notification-only watcher and is still the tool LinuxServer.io explicitly recommends for image-update notifications. WUD is used here because this homelab benefits from its Web UI/API, per-container version visibility, manual trigger support and Home Assistant integration possibilities. Automatic update triggers remain disabled.

## Registry choice

LinuxServer images are referenced through their official GitHub Container Registry (`ghcr.io/linuxserver/...`) rather than the `lscr.io` vanity endpoint. This avoids WUD's LSCR-specific registry/credential handling while still using LinuxServer's official published images.

## Docker socket note

WUD reads Docker metadata through `/var/run/docker.sock`. The mount is marked read-only at the filesystem level, but Docker daemon access is still security-sensitive. Keep WUD reachable only from trusted networks or behind authenticated access.

## Rollback preparation

Before a major application update, back up the corresponding `/share/Config/<service>` directory. For particularly sensitive services, consider pinning a known-good image tag before upgrading and record the previous tag so it can be restored quickly.
