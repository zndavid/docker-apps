#!/bin/sh
set -eu

# Run on the NAS after deployment. Creates and removes only its own probe files.
# abc is the LinuxServer application user, so this also checks app permissions.
docker exec --user abc "${RADARR_CONTAINER:-radarr}" /bin/sh -eu -c '
  source_dir=$(mktemp -d /data/torrents/.hardlink-check.XXXXXX)
  target_dir=""
  cleanup() {
    rm -f "$source_dir/probe"
    rmdir "$source_dir"
    if [ -n "$target_dir" ]; then
      rm -f "$target_dir/probe"
      rmdir "$target_dir"
    fi
  }
  trap cleanup EXIT
  trap '\''exit 130'\'' HUP INT TERM
  target_dir=$(mktemp -d /data/media/.hardlink-check.XXXXXX)
  printf "%s\n" "hardlink probe" > "$source_dir/probe"
  ln "$source_dir/probe" "$target_dir/probe"
  test "$(stat -c "%d:%i" "$source_dir/probe")" = "$(stat -c "%d:%i" "$target_dir/probe")"
  printf "%s\n" "PASS: Radarr app user can hardlink from /data/torrents to /data/media"
'
