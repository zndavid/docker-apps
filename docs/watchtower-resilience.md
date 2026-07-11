# Watchtower resilience

The stack is configured so Watchtower can update containers without leaving the whole media stack stopped.

Key safeguards:

- `WATCHTOWER_LABEL_ENABLE=true` limits updates to containers that explicitly opt in with `com.centurylinklabs.watchtower.enable=true`.
- `WATCHTOWER_ROLLING_RESTART=true` updates one container at a time instead of stopping a large part of the stack at once.
- `WATCHTOWER_INCLUDE_RESTARTING=true` allows Watchtower to handle containers that are already in a restart loop.
- `WATCHTOWER_REVIVE_STOPPED=true` starts eligible stopped containers when their image is updated, which reduces the chance that manual intervention is needed after a failed update window.
- `restart: unless-stopped` remains the default restart policy for application containers.
- `autoheal` restarts containers that become `unhealthy` and have the `autoheal=true` label.

Operational notes:

- Containers without a healthcheck can still be updated by Watchtower, but Autoheal cannot restart them based on health state.
- Watchtower and Autoheal both need read access to `/var/run/docker.sock`; keep these services restricted to trusted hosts only.
- If a specific app should not be automatically updated, remove its `com.centurylinklabs.watchtower.enable=true` label or override the label to `false`.
- If a specific app should not be restarted by Autoheal, remove its `autoheal=true` label or override the label to `false`.

Recommended checks after deployment:

```bash
docker compose config
docker compose up -d
docker compose ps
```

To inspect an update or healing event:

```bash
docker logs watchtower
docker logs autoheal
```
