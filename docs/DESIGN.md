# Design

## Services

```
browser ──HTTPS/WSS──▶ caddy:443 ──▶ realm:8090 ──WS relay──▶ realmd:3724 / mangosd:8085
                                       │  ▲                        │        │
                                       │  └─ SOAP http://mangosd:7878       │
                                       ├─ mysql://realmweb@mariadb ◀────────┘ (mangos user)
                                       ├─ /client/Data (ro)   ← operator's archives
                                       ├─ /config             ← *.conf (shared with the game)
                                       └─ /state              ← realm.sqlite, master.key
```

| service | image | role | ports |
|---|---|---|---|
| `caddy` | caddy:2 | TLS, HTTP/3, compression, security headers | **80, 443** (only published ports) |
| `realm` | wenilla-realm | play page, auth, `/data` file service, `/ws` relay, admin panel, SOAP client | 8090 internal |
| `realmd` | wenilla-realm-mangos | game login server | 3724 internal |
| `mangosd` | wenilla-realm-mangos | world server (+playerbots, ahbot), SOAP | 8085, 7878 internal |
| `mariadb` | mariadb:11.4 | four databases | 3306 internal |
| `db-init` | wenilla-realm-mangos | one-shot: schema install, users, realmlist, conf seeding | — |
| profiles `extract`, `backup` | mangos / mariadb images | on-demand jobs | — |

Volumes: `db`, `config`, `gamedata` (dbc/maps/vmaps/mmaps), `state`, `mangoslogs`,
`caddy_data`, `caddy_config`. Bind mounts: the operator's `Data/` (ro), `./backups`.

## Data flow: login to world

1. Player opens `https://realm/`, posts username/password to the service. It verifies
   against `realm.sqlite`, sets a session cookie.
2. `GET /api/play` returns the play page: the wasm loader plus a short-lived, single-use
   game credential for this session (the service knows the game account's password because
   it created the account through SOAP; the browser never sees a long-lived secret).
3. The wasm client boots, fetches `wenilla_bg.wasm(.br)` from `/app/www`, and requests
   archive members via `GET /data/<name>` — answered from `/client/Data`, cookie-gated,
   immutable-cached.
4. The client opens `wss://realm/ws/3724`; the relay dials `realmd:3724` and pipes bytes.
   SRP6 login happens inside that tunnel exactly as with a native client. `realmd` reports
   the realm's address as `REALM_DOMAIN:8085`; the client maps it to `wss://realm/ws/8085`,
   and the relay dials `mangosd:8085`.
5. Character list, world, play. One WebSocket per tab per phase; the relay only ever dials
   `REALMD_HOST:3724` and `MANGOSD_HOST:8085`.

## Setup and administration

First boot: the service finds no admin, writes `/state/setup-token`, logs
`SETUP TOKEN: …`. `/setup` (token-gated) creates the admin login, then logs into SOAP as
classic-db's seeded `ADMINISTRATOR/ADMINISTRATOR`, sets a random password on it, stores the
password encrypted with `/state/master.key`, and updates `realmlist` (name, address) via
the `realmweb` grant. Afterwards the panel manages accounts (`account create/delete/set
password` over SOAP), rates and bot counts (`/config/*.conf` edits + `.reload config` or a
restart), announcements, and the online list (`realmweb` SELECTs).

## Config keys: hot vs restart

| change | applied by | needs |
|---|---|---|
| `Rate.*`, `PlayerSave.*`, most `mangosd.conf` gameplay keys | `.reload config` over SOAP | nothing |
| realm name / address (`realmlist`) | DB update | `realmd` re-reads it within ~20 s |
| `AiPlayerbot.*RandomBots*`, `ahbot.conf` | file edit | `mangosd` restart |
| `*DatabaseInfo`, `DataDir`, `BindIP`, ports, `SOAP.*`, `Console.Enable` | file edit | restart |
| `realmd.conf` (any) | file edit | `realmd` restart |
| `anticheat.conf` | file edit | `mangosd` restart |

`db-init`/`conf-defaults.sh` seed these files once; the service owns them afterwards.

## Why these choices

- **No native game ports**: the protocol is unencrypted and the servers were never
  hardened for the open internet; the relay puts everything behind TLS and a login.
- **Caddy, not the service, for TLS**: certificates, HTTP/3, and renewals are solved
  problems; the service stays a plain HTTP app.
- **SOAP over the Docker socket**: every admin action the panel needs is a GM command;
  container-level control is optional (EXTENSIONS.md).
- **Prebuilt images**: both builds take 20–30 min and 10+ GB; CI does them, the VM pulls.
- **Pinned upstreams, no patches**: reproducible source offer, simple to bump.
