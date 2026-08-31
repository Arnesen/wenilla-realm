#!/usr/bin/env bash
# mangosd start guard. This core HARD-ASSERTS at "Starting Map System" when mmap.enabled = 1
# and /data/mmaps is missing (loadMap(): itr != loadedMMaps.end()) — found on the first real
# deployment. Movement maps are optional data (realmctl extract --mmaps, or import-datapack);
# align the config with what is actually on disk, loudly, on every start.
set -euo pipefail
if ls /data/mmaps/*.mmap >/dev/null 2>&1; then
  if grep -qE '^mmap.enabled *= *0' /config/mangosd.conf; then
    echo "mangosd-start: /data/mmaps present — enabling pathfinding (mmap.enabled = 1)"
    sed -i 's|^mmap.enabled *=.*|mmap.enabled = 1|' /config/mangosd.conf
  fi
else
  if ! grep -qE '^mmap.enabled *= *0' /config/mangosd.conf; then
    echo "mangosd-start: NO movement maps in /data/mmaps — setting mmap.enabled = 0 so the"
    echo "mangosd-start: server can run. NPCs and bots path crudely without them; generate with"
    echo "mangosd-start: 'realmctl extract --mmaps' (hours) or copy them in with 'realmctl import-datapack'."
    sed -i 's|^mmap.enabled *=.*|mmap.enabled = 0|' /config/mangosd.conf
  fi
fi
exec mangosd -c /config/mangosd.conf -a /config/ahbot.conf -p /config/aiplayerbot.conf
