# Privacy

This is a self-hosted package; the operator is the data controller for their realm. What the
stack stores, so you can tell your players honestly:

| data | where | why | retention |
|---|---|---|---|
| web login username, password hash, display name | `realm.sqlite` | authentication | until the account is deleted |
| web session and login IP addresses | `realm.sqlite` | abuse handling, rate limiting | 90 days, then purged by the service |
| game account (username, SRP verifier) | `classicrealmd.account` | the game server's own login | until deleted |
| characters, inventory, chat channels joined, mail, guild, position | `classiccharacters` | the game | until deleted |
| in-game chat | not stored (the server logs GM commands only) | — | — |
| game-server IP column (`account.last_ip`) | `classicrealmd` | set by `realmd` | always the relay's container IP, never the player's |
| browser-side settings (key bindings, macros, layouts) | the player's `localStorage` | client config | until the player clears site data |

Nothing is sent anywhere else: no analytics, no telemetry, no third-party requests from
the play page (the CSP allows the realm origin only). Caddy access logs are off by default.

**Deletion on request**: the panel deletes a web login and its game account with all
characters. Backups age out after 14 days (`RETENTION`); if you keep off-site copies, they
are yours to purge. Player names appear in other players' mail and guild rosters, which the
game keeps as content of *those* players.
