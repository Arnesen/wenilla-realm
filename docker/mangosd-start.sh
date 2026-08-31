#!/usr/bin/env bash
# mangosd start guard. This core HARD-ASSERTS at "Starting Map System" when mmap.enabled = 1
# and /data/mmaps is missing (loadMap(): itr != loadedMMaps.end()) — found on the first real
# deployment. Movement maps are optional data (realmctl extract --mmaps, or import-datapack);
# align the config with what is actually on disk, loudly, on every start.
set -euo pipefail
if ls /data/mmaps/*.mmap >/dev/null 2>&1; then
  if ! grep -qE '^mmap.enabled *= *1' /config/mangosd.conf; then
    echo "mangosd-start: /data/mmaps present — enabling pathfinding (mmap.enabled = 1)"
    sed -i 's|^mmap.enabled *=.*|mmap.enabled = 1|' /config/mangosd.conf
  fi
else
  # This core cannot run without movement maps: the grid loader asserts on the first tile
  # regardless of mmap.enabled (verified on the first real deployment). Hold here with a clear
  # message instead of letting mangosd crash-loop; a restart after the maps arrive proceeds.
  echo "mangosd-start: NO movement maps in /data/mmaps — the world server REQUIRES them and"
  echo "mangosd-start: will not be started. Get them with ONE of:"
  echo "mangosd-start:   ./realmctl extract              (generates everything, incl. mmaps: HOURS on a small VM)"
  echo "mangosd-start:   ./realmctl import-datapack DIR  (copy a dbc/maps/vmaps/mmaps tree from another machine)"
  echo "mangosd-start: then: docker compose restart mangosd"
  echo "mangosd-start: waiting..."
  exec sleep infinity
fi
exec mangosd -c /config/mangosd.conf -a /config/ahbot.conf -p /config/aiplayerbot.conf
