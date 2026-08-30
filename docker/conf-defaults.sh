#!/usr/bin/env bash
# conf-defaults.sh — seed /config/*.conf from the image's *.conf.dist ONCE.
# Existing files are never touched: the realm service edits mangosd.conf,
# aiplayerbot.conf and ahbot.conf in place after setup.
set -euo pipefail
: "${DB_MANGOS_PASSWORD:?}"
SRC=/opt/mangos/etc
DST="${CONFIG_DIR:-/config}"
DBH="mariadb;3306;mangos;${DB_MANGOS_PASSWORD}"

mkdir -p "${DST}"
for dist in "${SRC}"/*.conf.dist; do
  name="$(basename "${dist}" .dist)"           # mangosd.conf, realmd.conf, ...
  out="${DST}/${name}"
  if [ -f "${out}" ]; then echo "keep ${out}"; continue; fi
  echo "seed ${out}"
  cp "${dist}" "${out}"
  case "${name}" in
    mangosd.conf)
      sed -i \
        -e "s|^LoginDatabaseInfo .*|LoginDatabaseInfo     = \"${DBH};classicrealmd\"|" \
        -e "s|^WorldDatabaseInfo .*|WorldDatabaseInfo     = \"${DBH};classicmangos\"|" \
        -e "s|^CharacterDatabaseInfo .*|CharacterDatabaseInfo = \"${DBH};classiccharacters\"|" \
        -e "s|^LogsDatabaseInfo .*|LogsDatabaseInfo      = \"${DBH};classiclogs\"|" \
        -e 's|^DataDir = .*|DataDir = "/data"|' \
        -e 's|^LogsDir = .*|LogsDir = "/logs"|' \
        -e 's|^BindIP = .*|BindIP = "0.0.0.0"|' \
        -e 's|^Console.Enable = .*|Console.Enable = 0|' \
        -e 's|^SOAP.Enabled = .*|SOAP.Enabled = 1|' \
        -e 's|^SOAP.IP = .*|SOAP.IP = 0.0.0.0|' \
        -e 's|^Ra.Enable = .*|Ra.Enable = 0|' \
        "${out}"
      ;;
    realmd.conf)
      # WrongPass.MaxCount = 0: every login arrives from the relay's container IP,
      # so an IP ban would lock out every player. The web layer rate-limits instead.
      sed -i \
        -e "s|^LoginDatabaseInfo .*|LoginDatabaseInfo = \"${DBH};classicrealmd\"|" \
        -e 's|^LogsDir = .*|LogsDir = "/logs"|' \
        -e 's|^BindIP = .*|BindIP = "0.0.0.0"|' \
        -e 's|^WrongPass.MaxCount = .*|WrongPass.MaxCount = 0|' \
        "${out}"
      ;;
    aiplayerbot.conf)
      sed -i \
        -e 's|^AiPlayerbot.MinRandomBots = .*|AiPlayerbot.MinRandomBots = 50|' \
        -e 's|^AiPlayerbot.MaxRandomBots = .*|AiPlayerbot.MaxRandomBots = 50|' \
        -e 's|^AiPlayerbot.RandomBotAccountCount = .*|AiPlayerbot.RandomBotAccountCount = 50|' \
        "${out}"
      # a playerbot DB key exists in some module versions; point it at the same server if so
      sed -i -E "s|^(AiPlayerbot\.[A-Za-z]*DatabaseInfo) *=.*|\1 = \"${DBH};classiccharacters\"|" "${out}"
      ;;
    anticheat.conf)
      # Top-level `Enable` (first occurrence) swaps in the null anticheat. The browser
      # client cannot do the Warden module handshake, and a Win/x86 login would hang
      # at the character list with it on. `Warden.Enable` is a dead key — don't rely on it.
      sed -i '0,/^Enable = 1/s||Enable = 0|' "${out}"
      ;;
  esac
done
chmod 0640 "${DST}"/*.conf
chown mangos:mangos "${DST}"/*.conf 2>/dev/null || true
echo "==> conf-defaults done"
