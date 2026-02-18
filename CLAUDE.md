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
- **OCI labels**: `org.opencontainers.image.source` is set to link the GHCR package back to this repo

### CI/CD (`.github/workflows/publish.yml`)
- Publishes to GHCR at `ghcr.io/ablack94/docker-claude`
- Auth uses `GITHUB_TOKEN` (no PAT needed)
- **Trigger → tag mapping**:
  - Push to `main` → `:stable`
  - Git tag `v1.2.3` → `:1.2.3`, `:1.2`, `:1`
  - Manual `workflow_dispatch` → user-specified version and tag
- Uses GHA Docker layer caching and build provenance attestations

### Usage
```dockerfile
FROM ghcr.io/ablack94/docker-claude:stable AS claude
FROM debian:bookworm-slim
COPY --from=claude /usr/local/bin/claude /usr/local/bin/claude
```

