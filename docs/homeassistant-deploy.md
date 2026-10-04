# Independent Home Assistant stack

Home Assistant is now defined in `docker-compose.homeassistant.yml`, with project
name `homeassistant-stack`. It keeps the existing `/share/Config/homeassistant`
config directory, host networking, capabilities and security options. Routine
media changes no longer include its service in the media Compose project.

## One-time handover

Back up Home Assistant and stop/remove its container under the old media stack
before creating the separate stack; the fixed `homeassistant` name cannot be
owned by both projects. Follow the ownership transition in
[NAS deployment](nas-deploy.md). Do not run `down --volumes` or delete the config
folder. Home Assistant will be briefly unavailable during the handover.

In Portainer create a second Git stack:

| Setting | Value |
| --- | --- |
| Stack name | `homeassistant-stack` |
| Repository | `https://github.com/zndavid/docker-apps` |
| Reference | `refs/heads/main` |
| Compose path | `docker-compose.homeassistant.yml` |
| Environment | Your existing `TZ` |
| GitOps | Polling, 5 minutes after verification |
| Re-pull image / Force redeployment | Off |
| Additional paths | Empty |

Deploy it after removing the old container, then verify port `8123`, automations,
integrations and any existing Cloudflare Tunnel origin. Host networking and the
NAS address remain the same. This file does not require the media stack's VPN,
Telegram or WUD credentials. You can later move this separate project to the
mini-PC with a verified Home Assistant backup.

WUD on the same NAS can still detect the container and send notifications, but
`docker.auto` is excluded for Home Assistant. Apply HA image updates through
its own stack's **Pull and redeploy** or an explicit image change in Git, after
making a backup. Both Git stacks share the repository, so an unrelated commit
can cause Portainer to check both definitions; with force redeployment off, an
unchanged HA service should stay running.
