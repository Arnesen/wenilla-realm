#!/usr/bin/env bash
# backup.sh — realm + character DBs and the service's sqlite → /backups/realm-<UTC>.tar.gz
# Runs in the mariadb image (profile `backup`). Keeps the newest $RETENTION (14).
set -euo pipefail
: "${DB_ROOT_PASSWORD:?}"
DB_HOST="${DB_HOST:-mariadb}"
RETENTION="${RETENTION:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="$(mktemp -d)"; trap 'rm -rf "${WORK}"' EXIT
mkdir -p /backups

mariadb -h"${DB_HOST}" -uroot -p"${DB_ROOT_PASSWORD}" -e 'SELECT 1' >/dev/null

# World DB is reproducible from the image; only irreplaceable state is dumped.
mariadb-dump -h"${DB_HOST}" -uroot -p"${DB_ROOT_PASSWORD}" --single-transaction --quick \
  --databases classicrealmd classiccharacters > "${WORK}/db.sql"

# The service keeps realm.sqlite in WAL mode: a plain cp of the main file can miss
# committed pages, so prefer sqlite3's online backup when the tool is present.
if [ -f /state/realm.sqlite ]; then
  if command -v sqlite3 >/dev/null; then
    sqlite3 /state/realm.sqlite ".backup '${WORK}/realm.sqlite'"
  else
    cp /state/realm.sqlite "${WORK}/realm.sqlite"
    [ -f /state/realm.sqlite-wal ] && cp /state/realm.sqlite-wal "${WORK}/realm.sqlite-wal"
  fi
fi
[ -f /state/master.key ] && cp /state/master.key "${WORK}/master.key"

OUT="/backups/realm-${STAMP}.tar.gz"
tar -C "${WORK}" -czf "${OUT}.partial" . && mv "${OUT}.partial" "${OUT}"
chmod 600 "${OUT}"
echo "wrote ${OUT} ($(du -h "${OUT}" | cut -f1))"

mapfile -t OLD < <(ls -1t /backups/realm-*.tar.gz 2>/dev/null | tail -n +$((RETENTION + 1)))
[ "${#OLD[@]}" -gt 0 ] && { printf '%s\n' "${OLD[@]}" | xargs -r rm -f; echo "pruned ${#OLD[@]}"; }
exit 0
