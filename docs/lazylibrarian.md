# LazyLibrarian setup

LazyLibrarian is added to the existing media stack as a lightweight ebook automation service.

## Container layout

- Web UI: `http://<NAS-IP>:5299`
- Config: `/share/Config/lazylibrarian` -> `/config`
- Shared downloads: `/share/Downloads` -> `/downloads`
- Ebook library: `/share/Media/Books` -> `/books`

The container uses the same `PUID`, `PGID`, `TZ`, `media-net`, restart policy, security option and logging defaults as the other media services.

No Calibre Docker mod is enabled by default. This keeps the container lightweight and assumes downloaded EPUB files can be sent to Kindle without conversion. Conversion can be added later if it is actually needed.

## Start the service

```bash
mkdir -p /share/Config/lazylibrarian /share/Media/Books
docker compose pull lazylibrarian
docker compose up -d lazylibrarian
docker compose logs -f lazylibrarian
```

## qBittorrent

In LazyLibrarian, open **Settings -> Downloaders** and configure qBittorrent.

Because qBittorrent shares Gluetun's network namespace, use the Gluetun service from inside the Docker network:

- Host: `gluetun`
- Port: `18080` unless `QBITTORRENT_WEBUI_PORT` was changed
- Username/password: the existing qBittorrent Web UI credentials
- Category: use a dedicated category such as `books`

Use the built-in connection test before saving.

## Prowlarr

LazyLibrarian supports Torznab providers. Add the Torznab endpoint exposed by Prowlarr under **Settings -> Providers -> Torznab** and keep the API key only in LazyLibrarian's runtime config; do not commit it to this repository.

The Prowlarr service is reachable from LazyLibrarian as `http://prowlarr:9696` on `media-net`.

## Ebook library

Configure the ebook destination inside LazyLibrarian as:

```text
/books
```

Both LazyLibrarian and qBittorrent see the shared download tree under:

```text
/downloads
```

This keeps container paths consistent and avoids remote path mapping for the local Docker stack.

## Automatic Send to Kindle

LazyLibrarian can email the downloaded book automatically after it is added to the library.

Under **Settings -> Notifications -> Email**:

1. Configure the SMTP server and sender account.
2. Set **Email To** to the Kindle personal-document email address.
3. Enable **Notify on Download**.
4. Enable **Attach book on download**.
5. Send a test email.

The SMTP sender must also be allowed in the Amazon account's approved personal-document sender list.

The repository already contains placeholder SMTP variables in `.env.example`; real credentials must remain in the untracked `.env` file or in LazyLibrarian's own config.

## Initial validation

After setup, test the workflow with a legally obtained EPUB:

1. Add the book to LazyLibrarian.
2. Confirm the search provider returns the expected result.
3. Confirm the download is sent to qBittorrent with the `books` category.
4. Confirm post-processing imports the EPUB into `/books`.
5. Confirm the email notifier attaches and sends the EPUB successfully.

Only add conversion tooling if real-world files prove to need it.
