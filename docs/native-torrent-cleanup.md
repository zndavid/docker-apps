# Native Torrent Cleanup

The old `transmission-cleanup` container is no longer the preferred solution.

The stack can do the same job natively:

1. Transmission stops seeding once the global idle seeding limit is reached.
2. Sonarr and Radarr remove imported torrents after Transmission reports them as stopped and complete.

This repository now tracks that migration with [`scripts/configure-native-torrent-cleanup.sh`](/home/david/work/docker-apps/scripts/configure-native-torrent-cleanup.sh).

Default behavior:

- Transmission idle seeding limit: `5760` minutes (`4` days)
- Transmission ratio limit: disabled
- Sonarr `removeCompletedDownloads`: enabled
- Radarr `removeCompletedDownloads`: enabled
- Telegram success notification: sent if `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are present

Run it from the stack directory on the target host:

```bash
./scripts/configure-native-torrent-cleanup.sh
```

Notes:

- The script reads `TRANSMISSION_RPC_USER` and `TRANSMISSION_RPC_PASSWORD` from the repo `.env` file by default.
- Sonarr and Radarr API keys are read from their `config.xml` files by default.
- If your setup uses different paths or client IDs, override them with environment variables before running the script.
