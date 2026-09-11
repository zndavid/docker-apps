#!/bin/sh
set -eu

MARKER_FILE="${VPN_UP_MARKER_FILE:-/gluetun/vpn-up.timestamp}"
GLUETUN_CONTAINER="${GLUETUN_CONTAINER:-gluetun}"
QBITTORRENT_CONTAINER="${QBITTORRENT_CONTAINER:-qbittorrent}"
POLL_INTERVAL="${POLL_INTERVAL:-5}"
RECOVERY_DELAY="${RECOVERY_DELAY:-10}"
HEALTH_WAIT_TIMEOUT="${HEALTH_WAIT_TIMEOUT:-120}"

log() {
  printf '%s %s\n' "$(date -Iseconds 2>/dev/null || date)" "$*"
}

read_marker() {
  if [ -r "$MARKER_FILE" ]; then
    cat "$MARKER_FILE" 2>/dev/null || true
  fi
}

gluetun_health() {
  docker inspect \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
    "$GLUETUN_CONTAINER" 2>/dev/null || true
}

qbittorrent_running() {
  [ "$(docker inspect --format '{{.State.Running}}' "$QBITTORRENT_CONTAINER" 2>/dev/null || true)" = "true" ]
}

last_marker=""
log "Waiting for initial Gluetun VPN-up marker at ${MARKER_FILE}"

while [ -z "$last_marker" ]; do
  last_marker="$(read_marker)"
  if [ -z "$last_marker" ]; then
    sleep "$POLL_INTERVAL"
  fi
done

log "Recovery watcher armed; initial marker=${last_marker}"

while :; do
  current_marker="$(read_marker)"

  if [ -n "$current_marker" ] && [ "$current_marker" != "$last_marker" ]; then
    last_marker="$current_marker"
    log "Detected Gluetun VPN reconnect; waiting ${RECOVERY_DELAY}s before qBittorrent recovery"
    sleep "$RECOVERY_DELAY"

    waited=0
    while [ "$(gluetun_health)" != "healthy" ] && [ "$waited" -lt "$HEALTH_WAIT_TIMEOUT" ]; do
      sleep "$POLL_INTERVAL"
      waited=$((waited + POLL_INTERVAL))
    done

    if [ "$(gluetun_health)" != "healthy" ]; then
      log "Gluetun did not become healthy within ${HEALTH_WAIT_TIMEOUT}s; qBittorrent restart skipped"
      continue
    fi

    if qbittorrent_running; then
      log "Restarting qBittorrent after VPN recovery"
      if docker restart -t 30 "$QBITTORRENT_CONTAINER" >/dev/null; then
        log "qBittorrent restarted successfully"
      else
        log "qBittorrent restart failed"
      fi
    else
      log "qBittorrent is not running; leaving it stopped"
    fi
  fi

  sleep "$POLL_INTERVAL"
done
