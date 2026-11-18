#!/bin/sh
set -eu

command -v yt-dlp >/dev/null 2>&1 || {
  printf '%s\n' "error: install yt-dlp first, then rerun this script" >&2
  exit 1
}

mkdir -p data

python3 - <<'PY'
import json
import subprocess
from pathlib import Path

profile = "https://soundcloud.com/gh0styyx"

result = subprocess.run(
    ["yt-dlp", "--yes-playlist", "--dump-single-json", profile],
    check=True,
    capture_output=True,
    text=True,
)
profile_data = json.loads(result.stdout)

releases = []
for track in profile_data.get("entries", []):
    if not track:
        continue

    date = track.get("release_date") or track.get("upload_date") or ""
    if len(date) == 8 and date.isdigit():
        date = f"{date[:4]}-{date[4:6]}-{date[6:8]}"

    artwork = track.get("thumbnail") or ""
    if not artwork:
        thumbnails = track.get("thumbnails") or []
        if thumbnails:
            artwork = max(
                thumbnails,
                key=lambda item: (item.get("width") or 0) * (item.get("height") or 0),
            ).get("url", "")

    releases.append({
        "title": track.get("title") or "",
        "url": track.get("webpage_url") or track.get("url") or "",
        "date": date,
        "genre": track.get("genre") or "",
        "artwork": artwork,
    })

Path("data/releases.json").write_text(
    json.dumps(releases, ensure_ascii=False, indent=2) + "\n"
)
print(f"wrote {len(releases)} releases to data/releases.json")
print(f"tracks with artwork: {sum(bool(r['artwork']) for r in releases)}")
print(f"tracks with genre: {sum(bool(r['genre']) for r in releases)}")
PY

