"""Fail CI when a Gluetun change would leave qBittorrent unchanged in GitOps."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
LABEL = "io.github.zndavid.vpn-stack-revision"


def read_compose(path):
    return json.loads(subprocess.check_output([
        "docker", "compose", "--env-file", str(ROOT / ".env.example"),
        "-f", str(path), "config", "--format", "json",
    ], cwd=ROOT, text=True))


def validate_pair(current, previous=None):
    gluetun = current["services"]["gluetun"]
    qbittorrent = current["services"]["qbittorrent"]
    revision = gluetun.get("labels", {}).get(LABEL)
    if not revision or qbittorrent.get("labels", {}).get(LABEL) != revision:
        raise ValueError("Gluetun and qBittorrent must share a nonempty VPN revision label")
    if previous is not None:
        old = previous["services"]["gluetun"]
        if old != gluetun and old.get("labels", {}).get(LABEL) == revision:
            raise ValueError("Gluetun changed: bump x-vpn-stack-revision to recreate BOTH Gluetun and qBittorrent")


def main():
    current = read_compose(ROOT / "docker-compose.yml")
    base = os.environ.get("VPN_BASE_REF", "")
    previous = None
    if base and set(base) != {"0"}:
        if not re.fullmatch(r"[0-9a-fA-F]{40}", base):
            raise ValueError("VPN_BASE_REF must be a full commit SHA")
        old_text = subprocess.check_output([
            "git", "show", f"{base}:docker-compose.yml",
        ], cwd=ROOT, text=True)
        with tempfile.TemporaryDirectory() as temporary:
            old_path = Path(temporary) / "compose.yml"
            old_path.write_text(old_text)
            previous = read_compose(old_path)
    validate_pair(current, previous)
    print("PASS: VPN revision labels agree" + (" and Gluetun changes coordinate both containers" if previous else " (no base commit for comparison)"))


if __name__ == "__main__":
    main()
