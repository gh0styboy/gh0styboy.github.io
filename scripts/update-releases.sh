#!/bin/sh
set -eu

profile="https://soundcloud.com/gh0styyx"

for cmd in yt-dlp jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    printf 'error: install %s first\n' "$cmd" >&2
    exit 1
  }
done

mkdir -p data content

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

metadata_file="$tmpdir/profile.json"
releases_file="$tmpdir/releases.jsonl"

yt-dlp --yes-playlist --dump-single-json "$profile" > "$metadata_file"
: > "$releases_file"

toml_quote() {
  jq -Rn --arg value "$1" '$value'
}

jq -c '.entries[]? | select(.)' "$metadata_file" |
while IFS= read -r track; do
  track_json="$tmpdir/track.json"
  printf '%s\n' "$track" > "$track_json"

  track_id=$(jq -r '.id // empty' "$track_json" |
    sed 's/[^a-zA-Z0-9_-]//g')
  [ -n "$track_id" ] || continue

  title=$(jq -r '.title // "untitled"' "$track_json")
  track_url=$(jq -r '.webpage_url // .url // empty' "$track_json")
  date=$(jq -r '.release_date // .upload_date // empty' "$track_json")
  description=$(jq -r '.description // empty' "$track_json")

  if printf '%s' "$date" | grep -Eq '^[0-9]{8}$'; then
    date=$(printf '%s' "$date" |
      sed 's/^\(....\)\(..\)\(..\)$/\1-\2-\3/')
  fi

  genre=$(jq -r '.genre // empty' "$track_json")

  artwork=$(jq -r '
    .thumbnail //
    (
      [.thumbnails[]?]
      | sort_by((.width // 0) * (.height // 0))
      | last
      | .url // empty
    ) //
    empty
  ' "$track_json")

  page="releases/$track_id/"
  content_file="content/release-$track_id.md"

  {
    printf '%s\n' '+++'
    printf 'title = %s\n' "$(toml_quote "$title")"
    printf 'path = %s\n' "$(toml_quote "releases/$track_id")"
    printf '%s\n' 'template = "song.html"'
    printf '\n%s\n' '[extra]'
    printf 'artwork = %s\n' "$(toml_quote "$artwork")"
    printf 'genre = %s\n' "$(toml_quote "$genre")"
    printf 'release_date = %s\n' "$(toml_quote "$date")"
    printf 'description = %s\n' "$(toml_quote "$description")"
    printf '\n%s\n' '[extra.platforms]'

    if [ -n "$track_url" ]; then
      printf 'soundcloud = %s\n' "$(toml_quote "$track_url")"
    fi

    printf '%s\n' '+++' ''
  } > "$content_file"

  jq -n \
    --arg id "$track_id" \
    --arg title "$title" \
    --arg url "$track_url" \
    --arg date "$date" \
    --arg genre "$genre" \
    --arg artwork "$artwork" \
    --arg description "$description" \
    --arg page "$page" \
    '{
      id: $id,
      title: $title,
      url: $url,
      date: $date,
      genre: $genre,
      artwork: $artwork,
      description: $description,
      page: $page
    }' >> "$releases_file"
done

if [ -s "$releases_file" ]; then
  jq -s '.' "$releases_file" > data/releases.json
else
  printf '%s\n' '[]' > data/releases.json
fi

count=$(jq 'length' data/releases.json)
printf 'generated %s release pages\n' "$count"

