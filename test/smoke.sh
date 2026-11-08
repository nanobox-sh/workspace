#!/usr/bin/env bash
# Runs the image the way nanobox runs it: uid 1000, an empty bind-mounted home,
# and the platform's env file and profile script mounted in. Every tool the
# image promises has to work from there.
set -euo pipefail

image="${1:?usage: test/smoke.sh IMAGE}"
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/nanobox"
printf "export NANOBOX_SMOKE='from the box env'\n" > "$tmp/nanobox/env"
printf '[ -r /etc/nanobox/env ] && . /etc/nanobox/env\n' > "$tmp/nanobox.sh"
chmod 0644 "$tmp/nanobox/env" "$tmp/nanobox.sh"

docker run --rm \
  --user 1000:1000 --workdir /home/dev \
  --tmpfs /home/dev:rw,uid=1000,gid=1000,mode=0755 \
  --mount "type=bind,source=$tmp/nanobox,target=/etc/nanobox,readonly" \
  --mount "type=bind,source=$tmp/nanobox.sh,target=/etc/profile.d/nanobox.sh,readonly" \
  --mount "type=bind,source=$here/inside.sh,target=/smoke.sh,readonly" \
  "$image" bash /smoke.sh
