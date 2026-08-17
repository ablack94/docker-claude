# docker-claude

## Summary
This repo contains a minimal Docker image for the Claude CLI.
It is intended as a build-time base image — consumers `COPY --from=` the binary into their own images. Not intended for run-time usage.

## Architecture

### Dockerfile
- **Base**: `debian:bookworm-slim`
- **Build arg**: `CLAUDE_VERSION` (default: `stable`) — accepts `stable`, `latest`, or a semver like `2.1.37`
- **Install**: Uses the official `https://claude.ai/install.sh` bootstrap script, which downloads and verifies the binary via SHA256 checksum
- **Binary location**: `/usr/local/bin/claude` (symlinked from `/root/.local/bin/claude`)
- **Version file**: installed version is written to `/etc/claude-version` (bare semver + newline) at build time
- **Version pin check**: if `CLAUDE_VERSION` is a concrete semver, the build fails unless `claude --version` matches it
- **OCI labels**: `org.opencontainers.image.source` is set to link the GHCR package back to this repo

### CI/CD (`.github/workflows/publish.yml`)
- Publishes to GHCR at `ghcr.io/ablack94/docker-claude`
- Auth uses `GITHUB_TOKEN` (no PAT needed)
- **Version resolution**: before building, `stable`/`latest` are resolved to a concrete semver via `https://downloads.claude.ai/claude-code-releases/<stable|latest>` (the same endpoint `install.sh` uses; plain-text semver body). The literal `stable`/`latest` is never passed as the `CLAUDE_VERSION` build arg — every published image is pinned
- **OCI labels**: `org.opencontainers.image.version` is set to the resolved semver
- **Trigger → tag mapping**:
  - Push to `main`, and daily scheduled runs (04:17 UTC) → `:stable`, `:X.Y.Z`, `:X.Y`, `:X` for the resolved version
  - Scheduled runs check GHCR first and skip cleanly if the resolved version is already published
  - Git tag `v1.2.3` → `:1.2.3`, `:1.2`, `:1`
  - Manual `workflow_dispatch` → user-specified version and tag
- Uses GHA Docker layer caching and build provenance attestations

### Usage
```dockerfile
FROM ghcr.io/ablack94/docker-claude:stable AS claude
FROM debian:bookworm-slim
COPY --from=claude /usr/local/bin/claude /usr/local/bin/claude
```

