# Operations

## Daily

| task | command |
|---|---|
| health | `./realmctl status` |
| logs | `./realmctl logs [mangosd\|realmd\|realm\|caddy\|mariadb]` |
| backup now | `./realmctl backup` → `backups/realm-<UTC>.tar.gz` (keeps 14) |
| nightly backups | `./realmctl install-cron` (04:17 local) |
| restore | `./realmctl restore backups/realm-<stamp>.tar.gz` (stops game services, restores, restarts) |
| update | `./realmctl update [service…]` (pull + `up -d`; recreates only what changed — `update realm` leaves the world server alone). Recreating `realm` drops every relay: players reload. See [RELEASE.md](RELEASE.md). |
| what is running | `./realmctl version` (image revisions vs `upstreams.env`) |
| roll back | `REALM_TAG=sha-<7>` in `.env`, then `./realmctl update realm` ([RELEASE.md](RELEASE.md)) |
| lost admin login | `./realmctl reset-admin` |

Backups contain the realm (accounts) and character databases, the service's
`realm.sqlite` and `master.key`. The world DB is not backed up: it is rebuilt from the
image by `db-init` on an empty database. Copy `backups/` off the VM (e.g. `rsync` or a
storage box) — a VM-local backup is not a backup.

## Dungeon presets

**Panel → Presets** makes a ready-to-play group of Alliance heroes — geared, talents spent,
standing at the entrance:

| preset | heroes | level | where they stand |
|---|---|---|---|
| The Deadmines | 5 | 20 | the mine in Moonbrook, Westfall |
| The Scarlet Monastery | 5 | 38 | the Monastery gates, Tirisfal Glades |
| The Sunken Temple | 5 | 52 | the stairs down to the portal, Swamp of Sorrows |
| Blackrock Depths | 5 | 56 | the gates inside Blackrock Mountain |
| Stratholme | 5 | 58 | the city gates, Eastern Plaguelands |
| Upper Blackrock Spire | 10 | 60 | the top of Blackrock Spire; the tank carries the Seal of Ascension |
| Molten Core | 40 | 60 | the Molten Span; everyone attuned — jump through the window |

A party is tank, healer and three damage dealers; UBRS adds a second warrior and two more healers;
Molten Core is a full raid (4 tanks, 13 healers, 23 damage). The level-60 groups wear pre-raid
gear (dungeon sets and epics). The service builds the characters itself, eight at a time across
the realm — about half a minute for a party, some six minutes for the raid — then logs in once as
each character's player to check that its level, talents and gear came through; the group's row
shows *building*, then *ready*, and its secret link.

Send the link to the group. Each friend opens it, clicks a card ("Warrior · Tank") and is in the
game as that character — no account, no password, no character screen. The same page is the
run's tool: who is in game, **Summon everyone to the entrance** (works online or offline), and
**Delete group**, which removes every account and character of the group (players online are
kicked first). Anyone with the link can use all three, so share it like a password and delete
the group when you are done; the panel lists and deletes groups too.

A card marked *failed* shows why (usually the world server was restarting); a note on a *ready*
card names gear the server would not let the character wear. Preset users do not
appear under Users. The presets need a running world with the classic-db content (the
characters are built in it); the characters are ordinary characters, saved and backed up like
any other until the group is deleted.

## Restart semantics

- **Panel "Restart world"**: the service asks `mangosd` to shut down cleanly; it saves every
  character, exits, and Compose (`restart: unless-stopped`) brings it back. Players see a
  disconnect and can log in again after the world reloads (2–5 min).
- **`docker compose restart mangosd`**: same path. `stop_grace_period: 5m` gives the save
  time; never shorten it.
- **Stop everything**: `./realmctl down`. Volumes persist. `docker compose down -v` deletes
  the database, config, extracted data and service state — only after a backup.
- **Config edits**: `mangosd.conf` rates and many limits are applied live by the panel via
  `.reload config`; database, port, `DataDir`, bot counts, and anything in `realmd.conf`
  need a restart of that service.
- `db-init` runs on every `up` and is idempotent: it skips the world install if the world DB
  exists, re-applies passwords/grants from `.env`, and never overwrites existing `/config` files.

## Sizing and limits

`mem_limit` on `mangosd` is `MANGOSD_MEM` in `.env` (default 3g; a fresh world with 50 bots is ~1.5 GB). Bots: 35 MB and a
slice of one core each; 50 is the default, 200 fits on 4 vCPU. Bump
`AiPlayerbot.MinRandomBots`/`MaxRandomBots` from the panel (restart). MariaDB defaults are
fine up to a few hundred characters.

Disk: images ~2 GB, world DB ~1 GB, extracted data 2–4 GB (mmaps add ~1 GB), client
`Data/` ~5 GB, backups ~50 MB each.

## Logs

Game server logs live in the `mangoslogs` volume (`Server.log`, `Realmd.log`,
`DBErrors.log`) — `docker compose exec mangosd tail -f /logs/Server.log`. The service and
Caddy log to stdout (`realmctl logs`). Rotate with Docker's `json-file` limits in
`/etc/docker/daemon.json` (`"log-opts": {"max-size": "50m", "max-file": "5"}`).

## Re-extracting

`docker compose run --rm extract rm /data/.extracted && ./realmctl extract --mmaps`.
`mangosd` reads `/data` at start, so restart it afterwards.
