Commanding kit (drop-in)

Purpose:
- Root files are the source-of-truth for the Commanding producer layer.
- Embedded dot copies are consumer projections used by repositories that consume the kit, including this repository when it self-consumes.
- Development and script improvements happen in root files first.

How to run:
- bash ./commanding.sh
- bash ./run.sh

Current script conventions:
- Bash source scripts live in sh/.
- PowerShell source scripts live in ps1/ and docker/ps1/.
- Runtime logs are written to logs/actions.log and logs/error.log.
- High-risk actions should ask for explicit confirmation.
- Script menus should use lib/ui.sh for banner, pause, key input, and runtime helpers.

Markers:
- Updated root scripts may contain a marker such as:
  Source-of-truth: root script. Embedded dot copies are projections.

Strengthened root shell scripts:
- sh/server.sh
- sh/docker.sh
- sh/test.sh
- sh/schema.sh
- sh/migration.sh
- sh/cache.sh
- sh/service.sh
- sh/inspection.sh
- sh/log.sh
- sh/composer.sh
- sh/deploy.sh
- sh/fixture.sh
- sh/route.sh

## Local proving Symfony app

This repository now contains a minimal Symfony application in the root only for producer-side proving of Commanding flows.
It exists to exercise server, cache, fixtures, routes, migrations, logs, tests, and patch-friendly file changes.
It is not part of the consumer dot snapshot and must remain excluded by export policy.

Primary root markers for the local proving app:
- `bin/console`
- `config/`
- `src/`
- `templates/`
- `migrations/`
- `tests/`
- `composer.json`

Primary export boundary:
- `policy/dot-export.yaml`


## Watchdog profiles

- `application-centric` — application boot/runtime is the primary subject.
- `tool-centric` — tool layer and menu/runtime contracts are the primary subject; the Symfony proving app is a secondary target.

`Commanding` uses the `tool-centric` profile.
