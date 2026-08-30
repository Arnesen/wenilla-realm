# Security

## Threat model

Internet-facing surface: **Caddy on 80/443 only.** Everything else — `realmd` 3724,
`mangosd` 8085, SOAP 7878, MariaDB 3306, the realm service 8090 — is on the Compose network
and never published. The game protocol has no transport encryption and 1.12-era
authentication; it only ever travels between containers, and between the browser and the
relay inside TLS.

Attackers therefore face: the web login, the WebSocket relay behind it, and the file
endpoint. The service gates `/data/*` (client assets from your archives) and `/ws/*` (the
relay) behind a session cookie: no login, no bytes. The play page is rendered per session.

## Controls

- **Closed registration.** Accounts exist only if the operator makes them.
- **SOAP is internal** and used by the service with a per-install random password for the
  `ADMINISTRATOR` account, set during `/setup` and stored encrypted with `/state/master.key`.
  The seeded `GAMEMASTER`/`MODERATOR`/`PLAYER` accounts keep their published passwords but
  are unreachable from outside: only the relay can speak to `realmd`, and only for
  logged-in web users.
- **Secrets**: `.env` (DB passwords), `/state` volume (`master.key`, `realm.sqlite`,
  `setup-token` until setup completes). `chmod 600 .env`. Backups contain `master.key`
  and password hashes — treat `backups/` as secret.
- **Least-privilege DB users**: `mangos` has rights on `classic%` only; `realmweb` can
  `SELECT` accounts/characters and `UPDATE realmlist`, nothing else. Root is used by
  `db-init`/backup jobs only.
- **`WrongPass.MaxCount = 0`** in `realmd.conf`: every game login arrives from the relay's
  container IP, so realmd's per-IP ban would lock out *all* players after a few typos.
  Brute-force protection is the web layer's job (login rate limit per account and per
  client IP). Do not "fix" this by raising the count.
- **Anticheat module off** (`anticheat.conf: Enable = 0`): the browser client cannot run
  the Warden handshake, and with it on the character list is withheld. Players are
  invited friends; cheating is a social problem here, not a technical one.
- **Non-root containers**: `realmd`/`mangosd` run as `mangos`, the service as `realm`.
  `db-init` and `extract` run as root for volume ownership and need no network exposure.
- **Headers**: HSTS, `nosniff`, `Referrer-Policy: no-referrer`, `Server` stripped.

## Do not

- Add `ports:` to `realmd`, `mangosd`, `mariadb`, or `realm`. If you want a native
  client, put it behind a VPN (WireGuard/Tailscale) — never on the public IP.
- Expose SOAP. It is unauthenticated-by-design GM access once the password is known.
- Reuse the DB passwords anywhere else.

## Reporting

Open a private security advisory on the repository, or email the maintainer listed there.
