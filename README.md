# wenilla-realm

A private, 1.12.1-compatible realm that your friends play **from a browser tab**. One VM,
one `docker compose up`: CMaNGOS `mangos-classic` + `classic-db` for the world, the
[wenilla](https://github.com/Arnesen/wenilla) browser client (Rust → WebAssembly), and a small
admin/relay service that renders the play page, proxies the game protocol over WebSockets, and
gives the operator a setup wizard and control panel. Caddy terminates HTTPS. No game ports are
ever published; nobody installs anything.

*Not affiliated with or endorsed by Blizzard Entertainment.* This package contains no game
data and downloads none: you supply the `Data/` folder of your own 1.12.1 client.

## Quickstart

1. **VM**: x86-64 with Docker Engine + Compose v2, ports 80/443 open, a domain with an A
   record pointing at it. Sizing (measured: the world server is ~2 GB with bots off, +~20 MB
   per random bot):

   | VM | e.g. | what it runs comfortably |
   |---|---|---|
   | 2 vCPU / 4 GB / 40 GB | Hetzner CX23 | a group of friends, **bots off** (the default); add 2 GB swap |
   | 4 vCPU / 8 GB | Hetzner CX33 / CPX32 | the same plus ~50 random bots (`MANGOSD_MEM=5g`) |

   Generate movement maps (`extract --mmaps`) on a workstation, not on the VM.
2. **Client data**: copy your client's `Data/` folder to the VM (`rsync -a Data/ vm:/srv/client/Data/`).
3. **Configure**: `git clone https://github.com/Arnesen/wenilla-realm && cd wenilla-realm`,
   then `./realmctl init` — a guided walk through the four things only you know (hostname,
   where your client's `Data/` is, whether to build movement maps) that explains each choice
   and its limits, generates the database passwords, and writes `.env`.
4. **Extract** the server's map data from your client once: `./realmctl extract` — or
   `./realmctl import-datapack <dir>` if you already have a `dbc/ maps/ vmaps/` tree.
5. **Start**: `./realmctl up`. It pulls the prebuilt images from `ghcr.io/arnesen/…` and
   prints a one-time setup token; open `https://<your-domain>/setup`, paste it, name the
   realm, create your admin login, then invite players from the panel (Users → Invite a friend).

Everything is on one machine and there is exactly one game world per install. The operator
creates every account; players need a WebGPU-capable browser (Chrome/Edge — Linux Chrome behind
`chrome://flags/#enable-unsafe-webgpu`) and nothing else.

Full walkthrough: [SETUP.md](docs/SETUP.md). Day two: [OPERATIONS.md](docs/OPERATIONS.md).

## What is inside

| Component | Role | License |
|---|---|---|
| [CMaNGOS mangos-classic](https://github.com/cmangos/mangos-classic) | game server (`realmd`, `mangosd`, extractors, playerbots, auction bot) | GPLv2 |
| [classic-db](https://github.com/cmangos/classic-db) | world database content | GPLv3 |
| [wenilla](https://github.com/Arnesen/wenilla) | browser client (wasm) + `wenilla-realm` admin/relay service | MIT OR Apache-2.0 |
| [Caddy](https://caddyserver.com), [MariaDB](https://mariadb.org) | HTTPS front, database | Apache-2.0, GPLv2 |
| this repository | compose, Dockerfiles, scripts, docs | MIT |

**Source offer (GPLv2 §3 / GPLv3 §6).** The published images build the upstream projects
*unpatched* at the commits pinned in [`upstreams.env`](upstreams.env). Every image carries
`org.opencontainers.image.source` and `org.opencontainers.image.revision` labels (plus
`dev.wenilla.classic-db.revision`); the exact sources are at those revisions in the upstream
repositories, and the Dockerfiles in `docker/` are the complete build recipe.

## Docs

[SETUP](docs/SETUP.md) · [OPERATIONS](docs/OPERATIONS.md) · [SECURITY](docs/SECURITY.md) · [PRIVACY](docs/PRIVACY.md)
· [LEGAL](docs/LEGAL.md) · [EXTENSIONS](docs/EXTENSIONS.md) · [DESIGN](docs/DESIGN.md)
