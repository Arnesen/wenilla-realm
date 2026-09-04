# Working in this repository

wenilla-realm packages a private, browser-played 1.12.1 realm for one VM: Docker Compose,
two images built by CI, the `realmctl` operator script, and the docs. The code that runs is
elsewhere — the client and the realm service are built from
[Arnesen/wenilla](https://github.com/Arnesen/wenilla) at the commit pinned in `upstreams.env`,
the game server from CMaNGOS at its pins. This file is the map for a person or an agent who has
to deploy, fix or change something here. The pipeline end to end, deploys, rollbacks and the
runbook are in [docs/RELEASE.md](docs/RELEASE.md).

## What lives where

| path | what |
|---|---|
| `upstreams.env` | the four pinned commits. `WENILLA_COMMIT` is rewritten by wenilla's pin bot on every push to its `main`; the other three move by hand. |
| `compose.yaml` | the stack: mariadb, db-init, realmd, mangosd, realm, caddy; profiles `extract`, `backup`. Only caddy publishes ports. |
| `docker/realm.Dockerfile` | the client + realm service image (built from wenilla at the pin, ~25 min in CI; do not build on the VM) |
| `docker/mangos.Dockerfile` + `docker/*.sh` | the game server image and the scripts it copies in; `backup.sh`/`restore.sh` are bind-mounted at run time |
| `realmctl` | the operator CLI: `init`, `up`, `update`, `version`, `status`, `logs`, `extract`, `backup`, `restore`, … |
| `.github/workflows/images.yml` | builds and pushes both images on every push to `main` (mangos only when its inputs changed) and on `v*` tags |
| `.github/workflows/smoke.yml` | after `images`: boots the stack without game data, checks `/healthz` and the setup gate. Does not gate the tags. |
| `caddy/Caddyfile` | TLS, HTTP/3, headers; proxies to `realm:8090` |
| `docs/` | SETUP, OPERATIONS, RELEASE, DESIGN, SECURITY, PRIVACY, LEGAL, EXTENSIONS |

## Commands

```bash
./realmctl version              # running image revisions vs upstreams.env
./realmctl update [service…]    # pull + up -d; recreates only what changed. `update realm` leaves the world server alone
./realmctl status | logs [svc]  # health, restart counts; follow logs
./realmctl backup | restore F   # DBs + service state → backups/; restore stops the game services first
gh run list -R Arnesen/wenilla-realm --workflow images     # is the build done? (20–25 min)
gh run list -R Arnesen/wenilla --workflow bump-realm-pin   # did the pin move?
```

There is no Docker on the development laptop; the images are built by CI and tested by `smoke`.
A change to `compose.yaml` or `realmctl` is exercised by `smoke.yml` (the web path only: no
game data in CI) and by the operator on the VM.

## Invariants

- **`WENILLA_COMMIT` is wenilla `main`'s head.** Never hand-edit it to a commit off `main`; the
  bot's ratchet refuses a non-descendant and fails loudly. Land the change on wenilla `main`.
- **A full commit hash, never a branch name**, for every pin: branch names are not reproducible builds.
- **No game data in the repository, ever.** `images.yml`'s first job refuses to build if an
  `.mpq`/`.dbc` is found; `.dockerignore` keeps them out of the context. The package ships none
  and downloads none (docs/LEGAL.md).
- **`.env` is the operator's and untracked.** `realmctl init` writes it (mode 600); `.env.example`
  documents every key.
- **The image labels are the source offer.** `org.opencontainers.image.source`/`.revision` are set
  by the Dockerfiles to the project and commit built; `images.yml` must not pass its own labels
  over them.
- **`smoke` does not gate `latest`.** A red smoke run means the tag is already published; read it
  before `realmctl update`.
- **`stop_grace_period: 5m` on `mangosd`** is the character save. Never shorten it.
- **The pin bot pushes to `main` here directly.** Protecting `main` against pushes would need a
  bypass for `github-actions[bot]`, or the bot's PAT owner.

## Where to look when

| symptom | look at |
|---|---|
| merged in wenilla, nothing happened here | the bot run in wenilla (`bump-realm-pin`): token missing/expired, or the ratchet refused |
| `images` red | `gh run view <id> --log-failed`; usually the wasm build — fix in wenilla |
| `realmctl update` changed nothing | `realmctl version`; the build may still be running; `.env` may pin a `sha-` tag |
| the VM runs something older than the pin | `realmctl version` vs `git log -1 -- upstreams.env`; then `realmctl update` |
| players lost their session after an update | expected: recreating `realm` drops the relays; they reload |
| the world server restarted for a client-only change | the `mangos-inputs` job in that `images` run; it should have retagged, not rebuilt |
