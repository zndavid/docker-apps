# Native Torrent Cleanup

The old `transmission-cleanup` container is no longer the preferred solution.

The stack can do the same job natively:

1. Transmission stops seeding once the global idle seeding limit is reached.
2. Sonarr and Radarr remove imported torrents after Transmission reports them as stopped and complete.

This repository configures that behavior with [`configure-native-torrent-cleanup.sh`](../scripts/configure-native-torrent-cleanup.sh).

Default behavior:

- Transmission idle seeding limit: `5760` minutes (`4` days)
- Transmission ratio limit: disabled
- Sonarr `removeCompletedDownloads`: enabled
- Radarr `removeCompletedDownloads`: enabled
- Telegram success notification: sent if `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are present

Run it from the repository root on the target host:

```bash
./scripts/configure-native-torrent-cleanup.sh
```

Notes:

- The script reads `TRANSMISSION_RPC_USER`, `TRANSMISSION_RPC_PASSWORD` and `TORRENT_IDLE_SEEDING_LIMIT_MINUTES` from the repository `.env` by default.
- Keep `.env` comments on separate lines; `.env.example` follows this convention.
- Sonarr and Radarr API keys are read from their `config.xml` files by default.
- The default Transmission download-client ID is `1` in both Arr applications. Override `SONARR_DOWNLOAD_CLIENT_ID` and `RADARR_DOWNLOAD_CLIENT_ID` if your installation uses different IDs.
- If your setup uses different paths or API endpoints, override the corresponding environment variables before running the script.
