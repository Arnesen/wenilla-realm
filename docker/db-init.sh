#!/usr/bin/env bash
# db-init.sh — one-shot, idempotent database bootstrap (runs before realmd/mangosd).
#   1. wait for MariaDB
#   2. install world/realm/char/logs DBs via classic-db's InstallFullDB.sh if the
#      world DB is empty (keeps classic-db's seeded ADMINISTRATOR/GAMEMASTER/... accounts:
#      the realm service logs in as ADMINISTRATOR on first setup and re-passwords it)
#   3. always: (re)apply users/grants from .env, upsert realmlist row 1
set -euo pipefail

: "${DB_ROOT_PASSWORD:?}" "${DB_MANGOS_PASSWORD:?}" "${DB_REALMWEB_PASSWORD:?}"
DB_HOST="${DB_HOST:-mariadb}"
REALM_DOMAIN="${REALM_DOMAIN:-localhost}"
CLASSICDB=/opt/src/classic-db
CORE=/opt/src/mangos-classic

root() { mariadb -h"${DB_HOST}" -uroot -p"${DB_ROOT_PASSWORD}" "$@"; }

echo "==> waiting for MariaDB at ${DB_HOST}"
for i in $(seq 1 60); do
  mariadb-admin -h"${DB_HOST}" -uroot -p"${DB_ROOT_PASSWORD}" ping --silent 2>/dev/null && break
  [ "$i" -eq 60 ] && { echo "MariaDB not reachable" >&2; exit 1; }
  sleep 2
done

# --- 2. world DB ------------------------------------------------------------
if [ -n "$(root -N -e "SHOW TABLES FROM classicmangos LIKE 'creature_template'" 2>/dev/null)" ]; then
  echo "==> world DB present; skipping InstallFullDB"
else
  echo "==> installing databases (this takes several minutes)"
  cat > "${CLASSICDB}/InstallFullDB.config" <<CFG
MYSQL_HOST="${DB_HOST}"
MYSQL_PORT="3306"
MYSQL_USERNAME="mangos"
MYSQL_PASSWORD="${DB_MANGOS_PASSWORD}"
MYSQL_USERIP="%"
MYSQL_COLSTAT=""
WORLD_DB_NAME="classicmangos"
REALM_DB_NAME="classicrealmd"
CHAR_DB_NAME="classiccharacters"
LOGS_DB_NAME="classiclogs"
MYSQL_PATH="$(command -v mariadb)"
CORE_PATH="${CORE}"
MYSQL_DUMP_PATH="$(command -v mariadb-dump)"
FORCE_WAIT="NO"
DEV_UPDATES="NO"
AHBOT="YES"
PLAYERBOTS_DB="YES"
CFG
  ( cd "${CLASSICDB}" && bash InstallFullDB.sh -InstallAll root "${DB_ROOT_PASSWORD}" DeleteAll )
  rm -f "${CLASSICDB}/InstallFullDB.config"
fi

# --- 3. users, grants, realmlist (every boot) --------------------------------
echo "==> applying users and grants"
root <<SQL
CREATE USER IF NOT EXISTS 'mangos'@'%' IDENTIFIED BY '${DB_MANGOS_PASSWORD}';
ALTER USER 'mangos'@'%' IDENTIFIED BY '${DB_MANGOS_PASSWORD}';
GRANT ALL PRIVILEGES ON \`classic%\`.* TO 'mangos'@'%';
GRANT PROCESS, RELOAD ON *.* TO 'mangos'@'%';

CREATE USER IF NOT EXISTS 'realmweb'@'%' IDENTIFIED BY '${DB_REALMWEB_PASSWORD}';
ALTER USER 'realmweb'@'%' IDENTIFIED BY '${DB_REALMWEB_PASSWORD}';
GRANT SELECT ON \`classicrealmd\`.* TO 'realmweb'@'%';
GRANT SELECT ON \`classiccharacters\`.* TO 'realmweb'@'%';
GRANT UPDATE ON \`classicrealmd\`.\`realmlist\` TO 'realmweb'@'%';
FLUSH PRIVILEGES;
SQL

echo "==> realmlist"
# Insert only if absent: after first boot the setup wizard owns name/address.
root classicrealmd <<SQL
INSERT INTO realmlist (id,name,address,port,icon,realmflags,timezone,allowedSecurityLevel,population,realmbuilds)
SELECT 1,'Realm','${REALM_DOMAIN}',8085,1,0,8,0,0,'5875'
WHERE NOT EXISTS (SELECT 1 FROM realmlist WHERE id=1);
UPDATE realmlist SET port=8085, realmbuilds='5875' WHERE id=1;
SQL

echo "==> db-init done"
