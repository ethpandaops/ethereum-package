#!/bin/sh
# Fetches a devnet's network-configs metadata bundle into /network-configs.
#
# The devnet is located through cartographoor's networks.json index (which maps
# every ethpandaops devnet name to its repository, path and branch). Networks it
# does not list yet (it refreshes every few hours) or that live under a
# devnet_repo override fall back to the naming convention cartographoor itself
# uses: <category>-<rest> -> <devnet_repo>/<category>-devnets/network-configs/<rest>.
#
# Inputs (env): NETWORK, DEVNET_REPO, CARTOGRAPHOOR_URL (empty skips the lookup).
set -eu

out=/network-configs
mkdir -p "$out"
repo=""
path=""
ref=""

if [ -n "${CARTOGRAPHOOR_URL:-}" ]; then
  if curl -fsS --retry 3 -o /tmp/networks.json "$CARTOGRAPHOOR_URL"; then
    entry=$(jq -c --arg n "$NETWORK" '.networks[$n] // empty' /tmp/networks.json)
    owner=$(printf '%s' "$entry" | jq -r '.repository // "" | split("/")[0]')
    if [ -n "$entry" ] && [ "$owner" = "$DEVNET_REPO" ]; then
      repo=$(printf '%s' "$entry" | jq -r .repository)
      path=$(printf '%s' "$entry" | jq -r .path)
      ref=$(printf '%s' "$entry" | jq -r '(.url // "" | capture("/tree/(?<r>[^/]+)/") | .r) // ""')
      echo "cartographoor: $NETWORK -> $repo/$path (status: $(printf '%s' "$entry" | jq -r '.status // "unknown"'))"
    else
      echo "cartographoor: no $DEVNET_REPO entry for $NETWORK, using the naming convention"
    fi
  else
    echo "cartographoor: $CARTOGRAPHOOR_URL unreachable, using the naming convention"
  fi
fi

if [ -z "$repo" ]; then
  case "$NETWORK" in
    *-*) ;;
    *) echo "error: '$NETWORK' is not a devnet name (<category>-<name>, e.g. glamsterdam-devnet-8)"; exit 1 ;;
  esac
  repo="$DEVNET_REPO/${NETWORK%%-*}-devnets"
  path="network-configs/${NETWORK#*-}"
fi

api="https://api.github.com/repos/$repo/contents/$path/metadata"
[ -n "$ref" ] && api="$api?ref=$ref"
if ! curl -fsS --retry 3 -o /tmp/listing.json "$api"; then
  echo "error: could not list $api (missing network or GitHub API rate limit)"
  if [ -f /tmp/networks.json ]; then
    echo "devnets known to cartographoor (active, or in the same category):"
    jq -r --arg c "${NETWORK%%-*}-" '.networks | to_entries[]
      | select(.value.repository and (.value.status == "active" or (.key | startswith($c))))
      | "  \(.key) (\(.value.status))"' /tmp/networks.json
  fi
  exit 1
fi

jq -r '.[] | select(.type == "file") | "\(.name) \(.download_url)"' /tmp/listing.json >/tmp/files
while read -r name url; do
  curl -fsS --retry 3 -o "$out/$name" "$url"
done </tmp/files

if [ ! -s "$out/genesis_validators_root.txt" ]; then
  echo "error: $repo/$path/metadata has no genesis_validators_root.txt"
  exit 1
fi
echo "fetched $(wc -l </tmp/files) files from github.com/$repo/tree/${ref:-HEAD}/$path/metadata"
