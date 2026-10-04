# Container update policy

WUD is pinned to **9.2.1**. It checks for image updates on Sundays at 12:00 in
`Europe/Vienna`, with up to one minute of jitter. Startup/event scans remain
disabled. The scheduled flow is:

1. Scan for new images.
2. Send Telegram update notifications.
3. Apply a chosen update manually after reviewing its release notes/backups.

The Docker trigger is named `docker.manual` and has `AUTO=false`, `PRUNE=false`.
No scheduled trigger recreates containers or prunes rollback images.

## WUD v9 migration and authentication

Back up `/share/Config/wud` before upgrading. WUD v9 uses a SQLite store and
migrates legacy Loki data; the backup is needed for a genuine v8 rollback.
Keep the same `/store` bind mount. Set private `WUD_ADMIN_USER` and
`WUD_ADMIN_PASSWORD` in Portainer before deployment. Compose has no password fallback; `.env.example` contains a validation
placeholder that must be replaced before deployment.

The `WUD_AUTH_ADMIN_*` variables bootstrap admin access, and users/passwords
persist in the database. Verify authentication after deployment and check the
Triggers screen shows the manual Docker trigger, not an old automatic updater.
The UI is at the configured `WUD_WEBUI_PORT` (default `13000`) on the NAS LAN.

## Choose how to apply an update

For an independent media service with a mutable tag such as `latest`, WUD's
manual Docker trigger can pull/recreate that selected container. It changes the
running image, not the Compose definition. For explicit version tags or digests,
update the Git reference instead so a future Portainer redeploy does not revert
the intended version. WUD itself is excluded from self-updates and is upgraded
through Git/Portainer deliberately.

Portainer GitOps applies **Compose configuration changes**. Keep **Re-pull image**
and **Force redeployment** off for normal polling; a merge still deploys deliberate
image-reference changes. WUD handles discovery and selected manual image updates.
Do not run an independent local Compose project alongside the Portainer stacks.

## Gluetun + qBittorrent must be updated together

Both are excluded from `docker.manual`, but still watched for notifications.
For **Git changes to Gluetun**, bump `x-vpn-stack-revision` in Compose. The shared
revision label changes both service configurations so Portainer recreates both
containers. CI compares Gluetun against the PR base/previous main commit and
rejects a Gluetun change without a revision bump. Require the Validate stack
check in GitHub branch protection before relying on unattended polling; polling
does not wait for CI. Runtime-variable changes are not visible to that Git
comparison: disable polling and recreate both containers together when changing
VPN credentials/countries/ports in Portainer, rather than updating only Gluetun.

qBittorrent shares Gluetun's network namespace. Recreating only Gluetun can leave
qBittorrent attached to the old namespace; do not apply individual WUD updates
or individual Portainer container recreation for this pair.

For targeted CLI maintenance of a Portainer-managed stack, use the same project
name (`media-stack`), the exact Git Compose revision and Additional paths used by
Portainer, and your private environment file. Do not use the stale pre-migration
checkout. Stop polling during maintenance and back up the configurations, then:

```bash
docker compose -p media-stack --env-file /path/to/private.env pull gluetun qbittorrent
docker compose -p media-stack --env-file /path/to/private.env up -d --no-deps --force-recreate gluetun qbittorrent
```

If you use the GPU override, pass the same `-f` files as the deployed stack. The
`--no-deps` invocation explicitly names both members and prevents unrelated
service recreation. This is targeted maintenance of the same project, not a
second deployment source; do not use it to change the Compose configuration.

Afterwards verify both services, compare namespaces and check VPN egress:

```bash
docker inspect qbittorrent --format '{{.HostConfig.NetworkMode}}'
docker inspect gluetun --format '{{.Id}}'
```

The qBittorrent `container:<ID>` value must refer to the current Gluetun container.
Follow [VPN egress verification](qbittorrent-gluetun.md#verify-vpn-egress), check
recovery logs, then re-enable polling. A full Portainer image refresh is broader
and does not replace checking that the pair was recreated together.

## Home Assistant, backups and Docker access

[Home Assistant](homeassistant-deploy.md) is a separate stack and excluded from
the media WUD Docker trigger. Update it deliberately through its own stack.

Before application upgrades, back up their config directories. `PRUNE=false`
retains old images, but does not undo database migrations or provide a full
rollback. Pin/restore a known-good image and compatible config backup if needed.

WUD's manual Docker updates require the Docker socket. That access is powerful;
a read-only filesystem mount of the socket would not restrict Docker API
operations. Keep WUD authenticated and on your trusted admin network.

- [WUD 9.2.1 release](https://github.com/getwud/wud/releases/tag/9.2.1)
- [WUD authentication](https://getwud.app/docs/configuration/authentications/)
- [Manual trigger setting](https://getwud.app/docs/configuration/triggers/)
