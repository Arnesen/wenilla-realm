#!/usr/bin/env bash
# restore.sh <realm-*.tar.gz> — restore DBs + service state. STOP realmd/mangosd/realm first
# (realmctl restore does). Overwrites classicrealmd, classiccharacters and /state.
set -euo pipefail
: "${DB_ROOT_PASSWORD:?}"
DB_HOST="${DB_HOST:-mariadb}"
FILE="${1:?usage: restore.sh /backups/realm-<stamp>.tar.gz}"
[ -f "${FILE}" ] || { echo "no such file: ${FILE}" >&2; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "${WORK}"' EXIT
tar -C "${WORK}" -xzf "${FILE}"

echo "restoring databases from ${FILE}"
mariadb -h"${DB_HOST}" -uroot -p"${DB_ROOT_PASSWORD}" < "${WORK}/db.sql"

if [ -f "${WORK}/realm.sqlite" ]; then
  rm -f /state/realm.sqlite /state/realm.sqlite-wal /state/realm.sqlite-shm
  cp "${WORK}/realm.sqlite" /state/realm.sqlite
  [ -f "${WORK}/realm.sqlite-wal" ] && cp "${WORK}/realm.sqlite-wal" /state/realm.sqlite-wal
  chown 10002:10002 /state/realm.sqlite* 2>/dev/null || true
fi
if [ -f "${WORK}/master.key" ]; then
  cp "${WORK}/master.key" /state/master.key; chmod 600 /state/master.key
  chown 10002:10002 /state/master.key 2>/dev/null || true
fi
echo "restore complete; start the stack with: realmctl up"
