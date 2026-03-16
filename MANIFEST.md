Commanding manifest

Root contract:
- Root shell, PowerShell, docker, git, policy, and helper files are the editable producer source.
- Embedded dot copies are runtime projections for consumers and are not the primary editing target.

Runtime contract:
- Menus should resolve project root through lib/ui.sh.
- Logs should go to logs/actions.log and logs/error.log.
- Menus should exit cleanly on Space, Enter, 0, or q where practical.
- Destructive actions should require confirmation.

Current strengthened source scripts:
- sh/server.sh
- sh/docker.sh
- sh/test.sh
- sh/schema.sh
- sh/migration.sh
- sh/cache.sh
- sh/service.sh
- lib/ui.sh

Operator note:
- The repository may self-consume Commanding through an embedded dot projection.
- That projection is part of runtime consumption, not a competing source tree.
- sh/inspection.sh
- sh/log.sh
- sh/composer.sh
- sh/deploy.sh
- sh/fixture.sh
- sh/route.sh

## Local proving app contract

- Root Symfony application is producer-side only.
- It exists to validate Commanding behavior on a real target.
- Consumer exports must exclude the proving app.
- Export boundary is defined in `policy/dot-export.yaml`.
- Commanding scripts should continue to operate relative to repository root and detect app capabilities by root markers.


## Watchdog

- Profile: `tool-centric`
- Primary: shell/menu/runtime contract checks
- Secondary: Symfony proving app compatibility
