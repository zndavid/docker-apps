# Container update policy

WUD is pinned to **9.2.1** and scans for image updates on Sundays at 12:00 in
`Europe/Vienna`, with up to one minute of jitter. Startup/event scans remain
disabled.

The scheduled flow is:

1. Scan all watched containers for new image versions/digests.
2. Send Telegram update notifications.
3. Automatically recreate eligible containers with the detected image.
4. Keep the previous image locally for rollback because pruning is disabled.

The automatic Docker trigger is named `docker.auto`. It executes automatically
with `WUD_TRIGGER_DOCKER_AUTO_AUTO=true` and is associated with containers by
default via `WUD_TRIGGER_DOCKER_AUTO_INCLUDEBYDEFAULT=true`. Digest changes for
mutable tags such as
`latest` are watched, so services can update even when the tag name itself does
not change.

## Services updated automatically

The regular media services are eligible for WUD automatic updates, including
Sonarr, Radarr, Prowlarr, Bazarr, Jellyfin, Seerr, Cloudflared and the
qBittorrent recovery helper.

WUD changes the running container image; Portainer remains the owner of the
Compose configuration. Normal GitOps polling keeps **Re-pull image** and
**Force redeployment** off, so a documentation/config poll does not deliberately
refresh every floating image again.

## Gluetun + qBittorrent stay coordinated

`gluetun` and `qbittorrent` are excluded from `docker.auto` with
`wud.trigger.exclude: docker.auto`.

qBittorrent shares Gluetun's network namespace. Recreating only Gluetun can
leave qBittorrent attached to the previous namespace, so the pair must still be
updated together through Git/Portainer.

For Git changes to Gluetun, bump `x-vpn-stack-revision` in Compose. The shared
revision label changes both service configurations so Portainer recreates both
containers. CI rejects a Gluetun change without that revision bump.

For targeted maintenance, stop polling first and update both members together:

```bash
docker compose -p media-stack --env-file /path/to/private.env pull gluetun qbittorrent
docker compose -p media-stack --env-file /path/to/private.env up -d --no-deps --force-recreate gluetun qbittorrent
```

If the Jellyfin GPU override is enabled, pass the same additional Compose file
used by Portainer. Afterwards verify the namespace relationship and VPN egress.

## WUD itself

WUD is intentionally not self-updated by its own Docker trigger. The WUD
container has `wud.watch=false` and stays pinned in Git so a Portainer redeploy
cannot unexpectedly restore a different version.

Upgrade WUD by changing the pinned image in Git, validating the stack and
letting Portainer deploy the reviewed commit. Keep `/share/Config/wud` backed
up before major-version upgrades because WUD stores persistent state there.

## Home Assistant

Home Assistant is a separate stack and is not managed by the media stack's WUD
trigger. Update it through its own Git/Portainer stack.

## Rollback and Docker access

`PRUNE=false` retains old images, but it does not roll back application
database migrations. Keep application config backups before unattended upgrades;
if an update is bad, pin a known-good image and restore a compatible config
backup when required.

Automatic updates require WUD to have write access to the Docker socket. Keep
WUD authentication enabled and expose its UI only on the trusted admin network.

- [WUD Docker trigger](https://getwud.app/docs/configuration/triggers/docker/)
- [WUD triggers](https://getwud.app/docs/configuration/triggers/)
