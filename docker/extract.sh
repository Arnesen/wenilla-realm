#!/usr/bin/env bash
# extract.sh — dbc/maps/vmaps (+ optional mmaps) from the operator's client at
# /client/Data into the gamedata volume at /data. Idempotent via /data/.extracted.
#
# Client layout: CMaNGOS' extractor expects Data/<locale>/*.MPQ, but merged-MPQ
# repackaged clients with no Data/enUS/ folder extract fine too (verified). If
# extraction stops with a locale error, create Data/enUS/ containing the locale
# MPQs (or symlinks to them) and rerun.
set -euo pipefail
TOOLS=/opt/mangos/bin/tools
OUT=/data

if [ -f "${OUT}/.extracted" ]; then
  echo "already extracted ($(cat "${OUT}/.extracted")); remove ${OUT}/.extracted to redo"; exit 0
fi
[ -d /client/Data ] || { echo "no /client/Data mounted (CLIENT_DATA in .env)" >&2; exit 1; }
ls /client/Data/*.[Mm][Pp][Qq] >/dev/null 2>&1 || ls /client/Data/*/*.[Mm][Pp][Qq] >/dev/null 2>&1 \
  || { echo "no .MPQ files under /client/Data" >&2; exit 1; }

# Step 1: DBC/maps/vmaps. "a" = non-interactive, all, every thread. Output lands in cwd.
# Its own mmaps phase fails outside the tools dir (upstream calls `sh MoveMapGen.sh`
# without a path), so we tolerate that and do mmaps ourselves below.
cd "${OUT}"
"${TOOLS}/ExtractResources.sh" a /client || true
for d in dbc maps vmaps; do
  [ -d "${OUT}/${d}" ] && [ -n "$(ls -A "${OUT}/${d}")" ] || { echo "extraction produced no ${d}/" >&2; exit 1; }
done

# Step 2: mmaps, run FROM the tools dir so MoveMapGen finds its binary, offmesh.txt
# and config.json (copied from the core's contrib/).
if [ "${EXTRACT_MMAPS:-0}" = "1" ]; then
  echo "generating mmaps (hours on a small VM)"
  cp -f /opt/src/mangos-classic/contrib/extractor_scripts/config.json "${TOOLS}/config.json"
  ( cd "${TOOLS}" && sh MoveMapGen.sh maps "${OUT}" "${OUT}/movemap.log" "${OUT}/movemap_detailed.log" all )
  [ -n "$(ls -A "${OUT}/mmaps" 2>/dev/null)" ] || { echo "mmaps produced no output" >&2; exit 1; }
else
  echo "EXTRACT_MMAPS!=1: skipping mmaps (NPC pathing falls back to straight lines)"
fi

date -u +%Y-%m-%dT%H:%M:%SZ > "${OUT}/.extracted"
chown -R 10001:10001 "${OUT}" 2>/dev/null || true
echo "extraction complete: $(du -sh "${OUT}" | cut -f1)"
