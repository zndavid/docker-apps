#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENV_FILE=${ENV_FILE:-"$SCRIPT_DIR/../.env"}

TORRENT_IDLE_SEEDING_LIMIT_MINUTES=${TORRENT_IDLE_SEEDING_LIMIT_MINUTES:-5760}
TRANSMISSION_RPC_URL=${TRANSMISSION_RPC_URL:-http://127.0.0.1:9091/transmission/rpc}
SONARR_API_URL=${SONARR_API_URL:-http://127.0.0.1:8989}
RADARR_API_URL=${RADARR_API_URL:-http://127.0.0.1:7878}
SONARR_DOWNLOAD_CLIENT_ID=${SONARR_DOWNLOAD_CLIENT_ID:-1}
RADARR_DOWNLOAD_CLIENT_ID=${RADARR_DOWNLOAD_CLIENT_ID:-1}
SONARR_CONFIG_PATH=${SONARR_CONFIG_PATH:-/share/Config/sonarr/config.xml}
RADARR_CONFIG_PATH=${RADARR_CONFIG_PATH:-/share/Config/radarr/config.xml}
TELEGRAM_API_URL=${TELEGRAM_API_URL:-https://api.telegram.org}

TRANSMISSION_SESSION_ID=""

log() {
  printf '%s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

read_env_file_value() {
  local key=$1

  [ -f "$ENV_FILE" ] || return 1
  sed -n "s/^${key}=//p" "$ENV_FILE" | tail -n 1
}

get_setting() {
  local key=$1
  local current_value=${!key:-}

  if [ -n "$current_value" ]; then
    printf '%s' "$current_value"
    return 0
  fi

  read_env_file_value "$key"
}

read_arr_api_key() {
  local env_key=$1
  local config_path=$2
  local current_value=${!env_key:-}

  if [ -n "$current_value" ]; then
    printf '%s' "$current_value"
    return 0
  fi

  [ -f "$config_path" ] || fail "Missing config file: $config_path"

  sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' "$config_path" | head -n 1
}

send_telegram_notification() {
  local message=$1
  local telegram_bot_token
  local telegram_chat_id

  telegram_bot_token=$(get_setting TELEGRAM_BOT_TOKEN || true)
  telegram_chat_id=$(get_setting TELEGRAM_CHAT_ID || true)

  if [ -z "$telegram_bot_token" ] || [ -z "$telegram_chat_id" ]; then
    log "Telegram: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID missing, skipping notification"
    return 0
  fi

  curl -fsS \
    --request POST \
    --data-urlencode "chat_id=$telegram_chat_id" \
    --data-urlencode "text=$message" \
    --data-urlencode "disable_web_page_preview=true" \
    "$TELEGRAM_API_URL/bot$telegram_bot_token/sendMessage" >/dev/null

  log "Telegram: success notification sent"
}

api_get() {
  local base_url=$1
  local api_key=$2
  local path=$3

  curl -fsS \
    --header "X-Api-Key: $api_key" \
    "$base_url$path"
}

api_put() {
  local base_url=$1
  local api_key=$2
  local path=$3
  local body=$4

  curl -fsS \
    --request PUT \
    --header "Content-Type: application/json" \
    --header "X-Api-Key: $api_key" \
    --data "$body" \
    "$base_url$path" >/dev/null
}

update_remove_completed_downloads() {
  local app_name=$1
  local base_url=$2
  local api_key=$3
  local client_id=$4

  local current_json
  local updated_json

  current_json=$(api_get "$base_url" "$api_key" "/api/v3/downloadclient/$client_id" | tr -d '\n')

  if ! printf '%s' "$current_json" | grep -Eq '"implementation"[[:space:]]*:[[:space:]]*"Transmission"'; then
    fail "$app_name download client $client_id is not a Transmission client"
  fi

  if printf '%s' "$current_json" | grep -Eq '"removeCompletedDownloads"[[:space:]]*:[[:space:]]*true'; then
    log "$app_name: removeCompletedDownloads already enabled"
    return 0
  fi

  updated_json=$(printf '%s' "$current_json" | sed 's/"removeCompletedDownloads":[[:space:]]*false/"removeCompletedDownloads":true/')

  if [ "$updated_json" = "$current_json" ]; then
    fail "$app_name: failed to update removeCompletedDownloads in payload"
  fi

  api_put "$base_url" "$api_key" "/api/v3/downloadclient/$client_id" "$updated_json"
  log "$app_name: enabled removeCompletedDownloads on Transmission client $client_id"
}

transmission_rpc() {
  local payload=$1
  local body_file
  local header_file
  local status_code
  local auth
  local curl_cmd

  body_file=$(mktemp)
  header_file=$(mktemp)
  auth="${TRANSMISSION_RPC_USER}:${TRANSMISSION_RPC_PASSWORD}"

  curl_cmd=(
    curl
    -sS
    --user "$auth"
    --header "Content-Type: application/json"
    --data "$payload"
    --dump-header "$header_file"
    --output "$body_file"
    --write-out '%{http_code}'
  )

  if [ -n "$TRANSMISSION_SESSION_ID" ]; then
    curl_cmd+=(--header "X-Transmission-Session-Id: $TRANSMISSION_SESSION_ID")
  fi

  curl_cmd+=("$TRANSMISSION_RPC_URL")
  status_code=$("${curl_cmd[@]}")

  if [ "$status_code" = "409" ]; then
    TRANSMISSION_SESSION_ID=$(sed -n 's/^X-Transmission-Session-Id: \(.*\)\r$/\1/p' "$header_file" | head -n 1)
    [ -n "$TRANSMISSION_SESSION_ID" ] || fail "Transmission RPC session id negotiation failed"

    status_code=$(curl -sS \
      --user "$auth" \
      --header "Content-Type: application/json" \
      --header "X-Transmission-Session-Id: $TRANSMISSION_SESSION_ID" \
      --data "$payload" \
      --output "$body_file" \
      --write-out '%{http_code}' \
      "$TRANSMISSION_RPC_URL")
  fi

  [ "$status_code" = "200" ] || fail "Transmission RPC request failed with HTTP $status_code"

  cat "$body_file"
  rm -f "$body_file" "$header_file"
}

configure_transmission() {
  local payload
  local result

  payload=$(cat <<EOF
{"method":"session-set","arguments":{"idle-seeding-limit-enabled":true,"idle-seeding-limit":$TORRENT_IDLE_SEEDING_LIMIT_MINUTES,"ratio-limit-enabled":false}}
EOF
)

  transmission_rpc "$payload" >/dev/null
  result=$(transmission_rpc '{"method":"session-get"}')

  printf '%s' "$result" | grep -q "\"idle-seeding-limit\":$TORRENT_IDLE_SEEDING_LIMIT_MINUTES" \
    || fail "Transmission idle-seeding-limit verification failed"
  printf '%s' "$result" | grep -q '"idle-seeding-limit-enabled":true' \
    || fail "Transmission idle-seeding-limit-enabled verification failed"
  printf '%s' "$result" | grep -q '"seedRatioLimited":false' \
    || fail "Transmission seedRatioLimited verification failed"

  log "Transmission: enabled idle seeding limit at ${TORRENT_IDLE_SEEDING_LIMIT_MINUTES} minutes"
}

main() {
  require_command curl
  require_command sed
  require_command grep

  TRANSMISSION_RPC_USER=$(get_setting TRANSMISSION_RPC_USER)
  TRANSMISSION_RPC_PASSWORD=$(get_setting TRANSMISSION_RPC_PASSWORD)
  [ -n "$TRANSMISSION_RPC_USER" ] || fail "Missing TRANSMISSION_RPC_USER"
  [ -n "$TRANSMISSION_RPC_PASSWORD" ] || fail "Missing TRANSMISSION_RPC_PASSWORD"

  SONARR_API_KEY=$(read_arr_api_key SONARR_API_KEY "$SONARR_CONFIG_PATH")
  RADARR_API_KEY=$(read_arr_api_key RADARR_API_KEY "$RADARR_CONFIG_PATH")
  [ -n "$SONARR_API_KEY" ] || fail "Missing Sonarr API key"
  [ -n "$RADARR_API_KEY" ] || fail "Missing Radarr API key"

  configure_transmission
  update_remove_completed_downloads "Sonarr" "$SONARR_API_URL" "$SONARR_API_KEY" "$SONARR_DOWNLOAD_CLIENT_ID"
  update_remove_completed_downloads "Radarr" "$RADARR_API_URL" "$RADARR_API_KEY" "$RADARR_DOWNLOAD_CLIENT_ID"

  send_telegram_notification "Native torrent cleanup configured successfully on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S %Z')."
  log "Native torrent cleanup is configured."
}

main "$@"
