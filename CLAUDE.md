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
- **Jobs**: `plan` → `publish` (matrix, one entry per version) → `update-readme`
- **Plan** (`.github/scripts/plan.sh`): resolves `stable`/`latest` to concrete semvers via `https://downloads.claude.ai/claude-code-releases/<stable|latest>` (the same endpoint `install.sh` uses; plain-text semver body), then decides per version:
  - `build` — version not yet in GHCR (or any push to `main`, since the Dockerfile may have changed)
  - `retag` — `:X.Y.Z` exists but some channel/rolling tag points elsewhere → `docker buildx imagetools create` carbon copy (digest unchanged, so `:X.Y.Z` stays immutable and attestations still apply)
  - nothing — every tag already points at `:X.Y.Z`
  - The literal `stable`/`latest` is never passed as the `CLAUDE_VERSION` build arg; every published image is pinned
- **Trigger → tag mapping**:
  - Push to `main` (ignores `**.md`), and scheduled polls every 30 min → `:stable` and `:latest` for their resolved versions, plus `:X.Y.Z`. `:X.Y`/`:X` go to the higher of the two versions, unless the other is on a different X.Y/X line
  - Polling exists because GitHub can't trigger on pushes to `anthropics/claude-code` (its CHANGELOG changes on each release); a no-op poll takes seconds
  - Git tag `v1.2.3` → `:1.2.3`, `:1.2`, `:1`
  - Manual `workflow_dispatch` → user-specified version and tag
- **README**: `update-readme` (`.github/scripts/update-readme.sh`) rewrites the block between `<!-- versions:start -->` / `<!-- versions:end -->` with the current stable/latest versions and pushes to `main` only if it changed. GITHUB_TOKEN pushes don't trigger workflows, so there's no loop. Requires `main` to allow pushes from `github-actions[bot]`
- **OCI labels**: `org.opencontainers.image.version` is set to the resolved semver
- Workflow-level `concurrency: publish` serializes runs (rolling tags + README commit)
- Uses GHA Docker layer caching and build provenance attestations

### Usage
```dockerfile
FROM ghcr.io/ablack94/docker-claude:stable AS claude
FROM debian:bookworm-slim
COPY --from=claude /usr/local/bin/claude /usr/local/bin/claude
```

