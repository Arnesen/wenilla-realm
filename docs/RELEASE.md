# Release flow

How a change travels from a pull request to a running realm, what each repository owns, and
what to do when something on that path breaks. Written to be followed by a person or an agent
with `git`, `gh` and SSH to the VM. The wenilla side (building the client, merging upstream
benilla) is in [wenilla's AGENTS.md](https://github.com/Arnesen/wenilla/blob/main/AGENTS.md)
and [docs/UPSTREAM.md](https://github.com/Arnesen/wenilla/blob/main/docs/UPSTREAM.md).

## The pipeline

```
samwhosung/benilla ── merged by hand, as a PR (wenilla docs/UPSTREAM.md) ──▶ Arnesen/wenilla  main
                                                                                    │
                                    bump-realm-pin.yml, on every push to main: writes WENILLA_COMMIT=<sha>
                                                                                    ▼
                                                              Arnesen/wenilla-realm  main: upstreams.env
                                                                                    │
                     images.yml, on every push to main: ghcr.io/arnesen/wenilla-realm:{sha-…, latest}
                                                        …-mangos too, but only when its own inputs changed
                                                                                    │
                     smoke.yml, after images: compose up without game data, /healthz, the setup gate
                                                                                    ▼
                                                              the VM:  ./realmctl update      (by hand)
```

| repository | owns | changes land as |
|---|---|---|
| [samwhosung/benilla](https://github.com/samwhosung/benilla) | the client | squashed snapshots; we never push there |
| [Arnesen/wenilla](https://github.com/Arnesen/wenilla) | the client + the browser port, the JavaScript bridge, the `wenilla-realm` service crate | PRs to `main` only; no force-push (repository ruleset); `check.yml` gates PRs |
| [Arnesen/wenilla-realm](https://github.com/Arnesen/wenilla-realm) (this repo) | packaging: compose, Dockerfiles, pins, `realmctl`, docs | PRs to `main`; the pin bot pushes to `main` directly |

Timing, measured: the pin lands within a minute of a wenilla merge; the images take 20–25
minutes; smoke another 5. A change merged in wenilla is pullable about half an hour later.
Nothing deploys itself: the VM changes only when someone runs `realmctl update`.

## What is in the images

**`ghcr.io/arnesen/wenilla-realm`** — `docker/realm.Dockerfile` clones wenilla at
`WENILLA_COMMIT`, runs `scripts/web-setup.sh` and `scripts/web-build.sh` (the wasm, its glue,
the pages' scripts, brotli/gzip siblings) and builds the `wenilla-realm` binary. `index.html`
is removed from the image: the service renders its own play page (`play.html`, compiled into
the binary). Contains no game data.

**`ghcr.io/arnesen/wenilla-realm-mangos`** — `docker/mangos.Dockerfile` builds mangos-classic,
classic-db and playerbots at their three pins, plus the four scripts it copies from `docker/`
(`db-init.sh`, `conf-defaults.sh`, `extract.sh`, `mangosd-start.sh`). It is rebuilt only when
one of those inputs changes; on every other push (a client pin bump is the usual one) CI points
this commit's `sha-…` tag at the current `latest` instead. So a client-only change does not
produce a new game-server image, and `realmctl update` after it leaves `mangosd` running.

Tags: `sha-<7 hex>` of the wenilla-realm commit that built it, `latest` for `main`, and
`<version>` for a `v*` tag. Labels: `org.opencontainers.image.source` and `.revision` name the
project and commit the image was built from (wenilla; mangos-classic, with classic-db under
`dev.wenilla.classic-db.*`). Those labels are the GPL source offer the README makes, and what
`realmctl version` reads. CI must not overwrite them — it did until this document's PR.

## The pin

`upstreams.env` pins four commits. Three move rarely and by hand (mangos-classic, classic-db,
playerbots). `WENILLA_COMMIT` is rewritten by wenilla's `bump-realm-pin.yml` on every push to
its `main`, and the invariant is:

> `WENILLA_COMMIT` is the head of wenilla's `main`. Every fix we carry lives on `main`; upstream
> benilla is merged into `main`. So "the pin is current" and "we ship upstream's latest plus our
> carries" are the same statement.

Consequences:

- **Do not hand-edit `WENILLA_COMMIT` to a commit off `main`.** The bot refuses to move the pin
  to a sha that does not descend from the current one (the ratchet) and fails loudly; a pin on a
  side branch would make every later `main` merge fail that check. Land the change on `main`.
- **Never use GitHub's "Sync fork" button on wenilla.** On a diverged fork its "discard commits"
  path hard-resets `main`. Upstream is brought in through a PR.
- The bot needs the `WENILLA_REALM_TOKEN` secret in wenilla: a fine-grained PAT with
  *Contents: read and write* on this repository. Fine-grained tokens expire; when the bot starts
  skipping, that is the first thing to check.

## Deploying

On the VM, in the checkout of this repository:

```bash
git pull                      # compose, realmctl and the docs move too; .env is yours and untracked
./realmctl version            # what is running, against what upstreams.env pins
./realmctl update             # pull, then up -d: recreates only the containers whose image changed
./realmctl update realm       # only the realm service (client + play page); leaves the world server alone
```

What a recreate costs the players:

- **`realm`**: every WebSocket relay drops. Players are disconnected and reload the page; the
  static files are served `no-cache`, so the reload fetches the new build. Seconds.
- **`mangosd`**: the world server saves every character (up to `stop_grace_period`, 5 minutes)
  and reloads the world, 2–5 minutes. Only happens when the mangos image or its config changed.

Verify: `./realmctl version` shows the wenilla revision the running `realm` container was built
from; `https://<domain>/healthz` answers; open the play page and, in the devtools console,
`wenilla.ready` turns true once the wasm has attached.

## Rolling back

Every image is also tagged with the wenilla-realm commit that built it. Pin the tag in `.env`
and update:

```bash
git log --oneline -- upstreams.env         # each pin commit names the wenilla change it shipped
sed -i 's|^REALM_TAG=.*|REALM_TAG=sha-762bdeb|' .env     # and/or MANGOS_TAG
./realmctl update realm
```

Put `REALM_TAG=latest` back afterwards, or the realm stays pinned through every later
`realmctl update`. A versioned release is the same thing with a nicer name: `git tag v0.1.0 &&
git push --tags` in this repository builds `<version>` tags of both images.

## When it breaks

| symptom | check | fix |
|---|---|---|
| merged in wenilla, no pin commit here | `gh run list -R Arnesen/wenilla --workflow bump-realm-pin` | *skipped*: the `WENILLA_REALM_TOKEN` secret is missing or expired — renew it, re-run the job. *failed on the ratchet*: the current pin is off `main` — set `WENILLA_COMMIT` to `main`'s head by hand in a commit to `main` here, then re-run. |
| pin moved, `images` red | `gh run list -R Arnesen/wenilla-realm --workflow images`, then `gh run view <id> --log-failed` | usually the wasm build (a wasm-only compile error upstream never sees; `check.yml` in wenilla exists to catch it first). Fix forward in wenilla; the merge re-pins and rebuilds. `latest` stays at the last green build; nothing changes on the VM. |
| `images` green, `smoke` red | `gh run view <id> --log-failed` for `smoke` | smoke does **not** gate the tags: `latest` is already published. Read what failed (db-init, `/healthz`, the setup gate) before updating the VM. |
| `realmctl update` changed nothing | `./realmctl version` vs `git log -1 -- upstreams.env` | the images may not be finished (20–25 min), or `.env` pins `REALM_TAG`/`MANGOS_TAG` to a `sha-…`. |
| the pin is not `main`'s head | `git log -3 -- upstreams.env` here; `git log -1 origin/main` in wenilla | that is the drift the ratchet and the ruleset guard against. Land whatever is missing on wenilla `main`; never hand-pin a side branch. |
| players see old behaviour after an update | `docker compose ps` — was `realm` recreated? | `./realmctl update realm`; a stale tab needs a reload (the page is `no-cache`, no hard reload needed). |
| the mangos image rebuilt for a client-only change | the `mangos-inputs` job's log in `images` | it diffs `docker/mangos.Dockerfile`, the four copied scripts and the three mangos pins against the previous push; a tag or a first push always builds. |

## History, briefly

The pin drifted three times in early September 2026: the soundscape fix (wenilla #14) sat
unmerged on a side branch on the theory that upstream syncing force-resets `main`, the pin was
hand-set to that branch, and the bot overwrote it on every later push to `main`, silently
dropping the fix each time while the comment in `upstreams.env` claimed otherwise. Syncing
does not force-reset anything; the one reset came from the "Sync fork" button. The fix was to
merge #14 into `main`, which made "pin = main's head" correct by construction; the ratchet and
the ruleset keep it that way.
