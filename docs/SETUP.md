# Setup

## 1. DNS and the VM

Create an A (and optionally AAAA) record for your hostname pointing at the VM's public IP.
Caddy requests a Let's Encrypt certificate on first start, which needs port 80 and 443
reachable and the record already resolving. WebGPU requires HTTPS, so there is no plain-HTTP
mode (for a laptop trial, `REALM_DOMAIN=localhost` uses Caddy's internal CA and the browser
will warn once).

Install Docker Engine + the Compose plugin (`docker compose version` must work). Sizing:
4 vCPU / 8 GB is comfortable for a dozen players and 50 bots; `mangosd` is capped at 5 GB
(`mem_limit`) and is single-threaded per continent, so a faster core beats more cores.

## 2. `.env`

```bash
git clone https://github.com/Arnesen/wenilla-realm && cd wenilla-realm
cp .env.example .env
$EDITOR .env      # REALM_DOMAIN, CLIENT_DATA, three passwords
```

Passwords: `openssl rand -hex 24`. They are written into `mangosd.conf`/`realmd.conf` on
first boot and into MariaDB grants on every boot, so changing them later in `.env` is enough
for the DB users but you must also edit the `.conf` files (`docker compose exec mangosd`).

## 3. Your client's `Data/` folder

You need a 1.12.1 (build 5875) client you own. Copy only its `Data/` directory to the VM:

```bash
rsync -a --info=progress2 "/path/to/client/Data/" vm:/srv/client/Data/
```

Point `CLIENT_DATA=/srv/client/Data` at it. It is mounted read-only into two containers:
the extractor (once) and the realm service (which serves single files from the archives to
browsers on demand; the archives themselves never leave the VM).

## 4. Server map data: extract or import

`mangosd` needs `dbc/`, `maps/`, `vmaps/` (and ideally `mmaps/`) derived from the client.

- `./realmctl extract` — dbc/maps/vmaps, ~10–20 min. `./realmctl extract --mmaps` also
  generates movement maps: hours on 4 vCPU, but NPCs and bots path properly. You can start
  without mmaps and rerun with `--mmaps` later (remove the marker: `docker compose run --rm
  extract rm /data/.extracted` first).
- `./realmctl import-datapack /path/to/pack` — if you already have a `dbc/ maps/ vmaps/
  [mmaps/]` tree from another install, copy it in instead (extraction is deterministic).

If extraction stops with a locale error, your client stores archives in `Data/enUS/` style
and the extractor wants them there; merged single-folder clients also work. See
`docker/extract.sh`.

## 5. First boot

```bash
./realmctl up
```

Order: MariaDB → `db-init` (installs the world DB from classic-db, several minutes; creates
DB users; seeds `/config/*.conf`) → `realmd`, `mangosd`, `realm`, `caddy`. `mangosd` then
loads the world (2–5 min); `./realmctl logs mangosd` shows progress, `./realmctl status`
shows health.

`realmctl up` prints the **setup token** (also `docker compose exec realm cat
/state/setup-token`). Open `https://<REALM_DOMAIN>/setup`, paste it, choose the realm name,
and create your admin login. The wizard logs into the game server's SOAP interface with the
database's seeded `ADMINISTRATOR` account, gives it a fresh random password, and stores it
encrypted under `/state`. The token file is deleted afterwards.

## 6. Players

From the panel: create an account (username + password, or an invite link), send the
player `https://<REALM_DOMAIN>/`. They log in on the web page, pick or create a character,
and play. Requirements on their side: a WebGPU-capable browser (Chrome/Edge on Windows/macOS,
Safari 26+, Firefox 141+; Chrome on Linux behind `chrome://flags/#enable-unsafe-webgpu`) and
a reasonable GPU. The first load fetches ~20 MB of compressed wasm, then game assets
on demand.

Registration is closed by design; every account is created by the operator.
