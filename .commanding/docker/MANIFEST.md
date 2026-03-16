# Docker Base (Commanding)

This folder is a reusable base for containerized dependencies across SmartResponsor consumers.

Contents:
- compose fragments: `docker/compose/compose-*.yml`
- service config: `docker/service/**`
- tools: `docker/tool/*.sh` and `docker/ps1/*.ps1`

Guarantees:
- Uses `docker compose` when available; falls back to `docker-compose`.
- No secrets committed.
- No consumer-specific app containers.
- Consumer override points are optional and safe.
