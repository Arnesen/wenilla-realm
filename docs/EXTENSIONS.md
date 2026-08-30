# Extensions

Things deliberately left out of the first release, with the seam they plug into.

## Discord login (next)

The service authenticates through a `Provider` trait (`crates/wenilla-realm/src/auth`).
The built-in provider is local username/password. A Discord OAuth2 provider maps a guild
membership (optionally a role) to a web login and auto-creates the game account on first
sign-in. Config: `REALM_AUTH=discord`, `DISCORD_CLIENT_ID/SECRET`, `DISCORD_GUILD_ID`,
`DISCORD_ROLE_ID` (optional). Registration stays closed: the guild *is* the allow-list.

## Any OIDC provider

Same trait: Keycloak, Authentik, Google Workspace, GitHub. Claims → display name;
`sub` → stable login id. Nothing else in the stack changes.

## Container control from the panel

The panel restarts `mangosd` by asking it to exit (cleanly, saving characters); Compose
restarts it. To let the panel *also* restart `realmd`, pull images, or read container
health, mount a socket proxy instead of the Docker socket:

```yaml
docker-proxy:
  image: tecnativa/docker-socket-proxy
  environment: { CONTAINERS: 1, POST: 1 }   # restart only; no exec/images/networks
  volumes: [/var/run/docker.sock:/var/run/docker.sock:ro]
```

and point `DOCKER_HOST=tcp://docker-proxy:2375` at it. Never mount the raw socket into a
service that faces the internet.

## Voluntary support link

The panel can show one operator-configured link ("help with the server bill") on the
player's account page. It is never shown before login, never gates any feature, account,
character, item, or rate, and is off by default. If that changes, the legal posture in
LEGAL.md no longer holds.

## Others worth doing

- Off-site backup target (`rclone` to S3/B2) as a `backup` profile sibling.
- Prometheus endpoint on the service (`/metrics`): online players, relay sessions, tick time.
- A read-only `armory` page fed from `classiccharacters` (already granted to `realmweb`).
