# Legal posture

This package is for running a **private, non-commercial** realm for a closed group of
friends, each of whom owns a copy of the 1.12.1-era client.

- **No game data is distributed.** The images contain server code and community-created
  database content only. The client archives come from the operator's own installation
  and are served to logged-in members of that operator's realm. CI refuses to build if
  any `.MPQ`/`.dbc` file is present in the repository.
- **No trademarks.** The project does not use the game's name, its world's name, or any
  publisher logos, in code, images, docs, or the play page. The realm is "a
  1.12.1-compatible realm". Keep it that way in your own branding.
- **Closed registration, no payments.** Access is by invitation of the operator; there is
  no sign-up form, no store, no donation gate. See EXTENSIONS.md for the one voluntary
  support link that is permitted and how it must not affect access.
- **Licenses honored.** CMaNGOS (GPLv2) and classic-db (GPLv3) are built unmodified at pinned
  commits; the images carry revision labels and the Dockerfiles are the full corresponding
  build. wenilla is MIT/Apache-2.0. This repository is MIT.

Not affiliated with or endorsed by Blizzard Entertainment.

## What not to do

- Do not host the client data or extracted server data anywhere public, including in
  the repository, image layers, releases, or a "convenience" download.
- Do not open registration to the public, advertise the realm, or charge for anything.
- Do not use the publisher's marks or artwork in the realm name, domain, page, or Discord.
- Do not remove the source-offer labels or the license table from the README when you fork.

This is not legal advice; laws differ by country and the publisher's EULA applies to your
client. If in doubt, ask a lawyer in your jurisdiction.
