# Commanding Docker Base

This folder provides **base container stacks** intended to be reused by **all consumers**.

Scope:
- Shared dependencies: Postgres, MySQL, Redis, RabbitMQ, MinIO, Prometheus, Grafana.
- Stable commands to start/stop/reset stacks.
- A small, predictable set of ports and credentials for local dev and JetBrains Data Sources.

Non-goals:
- App runtime (PHP/Nginx/Caddy) for a specific consumer.
- Secrets.
- Domain-specific add-ons (those belong to the consumer `deploy/` overrides).

## Stacks

- `db`  -> Postgres + MySQL (IDE Data Source baseline)
- `cache` -> Redis
- `mq` -> RabbitMQ
- `object` -> MinIO
- `obs` -> Prometheus + Grafana
- `all` -> db + cache + mq + object + obs

## Defaults

Ports (override via env):
- Postgres: `5432`
- MySQL: `3306`
- Redis: `6379`
- RabbitMQ: `5672` / UI `15672`
- MinIO: `9000` / Console `9001`
- Prometheus: `9090`
- Grafana: `3000`

Credentials (override via env):
- Postgres: `app/app/app`
- MySQL: `app/app/app` (root pass: `root`)
- RabbitMQ: `app/app`
- MinIO: `app/appappapp`
- Grafana: `admin/admin`

## Usage

### Bash (WSL / Git Bash)

From consumer repo root:

- Up DB stack: `.commanding/docker/tool/up.sh db`
- Reset DB stack (drops volumes): `.commanding/docker/tool/reset-db.sh`
- Up everything: `.commanding/docker/tool/up.sh all`
- Down everything: `.commanding/docker/tool/down.sh all`

### PowerShell

- Up DB: `.commanding\docker\ps1\up.ps1 db`
- Reset DB: `.commanding\docker\ps1\reset-db.ps1`

## Consumer overrides (no duplication)

If a consumer needs custom ports, networks, or extra services:

- Create `deploy/docker/compose-<stack>.override.yml` (optional)
- Or a shared `deploy/docker/compose.override.yml` (optional)

The tooling will automatically layer overrides when present:

- base: `.commanding/docker/compose/compose-db.yml`
- override: `deploy/docker/compose-db.override.yml` (if exists)
- global override: `deploy/docker/compose.override.yml` (if exists)

## JetBrains Data Source

1. Start DB stack.
2. In PhpStorm: add PostgreSQL and MySQL Data Sources.
3. Introspect/Synchronize.
4. If you use schema-qualified tables like `taxation.*`, enable that schema in the PostgreSQL Data Source.

## Mixed dialect SQL in one file

If a file contains both PostgreSQL and MySQL SQL strings, mark the string with a language injection:

- `/** @lang PostgreSQL */`
- `/** @lang MySQL */`

This prevents parser mismatch warnings like: `CONFLICT expected, got 'DUPLICATE'`.
