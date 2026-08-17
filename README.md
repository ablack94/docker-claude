# docker-claude

[![GHCR](https://ghcr-badge.egpl.dev/ablack94/docker-claude/size)](https://github.com/ablack94/docker-claude/pkgs/container/docker-claude)

Minimal Docker image containing the [Claude CLI](https://docs.anthropic.com/en/docs/claude-code), built on `debian:bookworm-slim`.

Primarily intended as a **build-time base image** — use `COPY --from=` to grab the Claude binary into your own images.

## Quick Start

### Pull the image

```bash
docker pull ghcr.io/ablack94/docker-claude:stable
```

### Use as a base image (recommended)

Copy the Claude CLI binary into your own Dockerfile:

```dockerfile
FROM ghcr.io/ablack94/docker-claude:stable AS claude

FROM debian:bookworm-slim
COPY --from=claude /usr/local/bin/claude /usr/local/bin/claude
# ... your application setup
```

### Run directly

```bash
docker run --rm -it ghcr.io/ablack94/docker-claude:stable --help
```

## Available Tags

| Tag | Description |
|-----|-------------|
| `stable` | Rolling pointer to the latest resolved `stable` Claude CLI release. Republished on every push to `main` and via a daily scheduled build that checks for new releases (moves without notice) |
| `x.y.z` | Immutable, pinned to a specific Claude CLI version (e.g. `1.2.3`) |
| `x.y` | Rolling pointer to the latest patch for a given minor version |
| `x` | Rolling pointer to the latest minor/patch for a given major version |

Every `stable` (and daily) publish is built against a concrete semver resolved at build time — the literal `stable`/`latest` channel names are never baked into a published image, so `:x.y.z` tags are always available alongside `:stable` for the same build.

**Recommendation**: pin an `:x.y.z` tag for reproducible builds. Use `:stable` only if you deliberately want to pick up new Claude CLI releases automatically.

## How It Works

- Installs the Claude CLI via the official [`claude.ai/install.sh`](https://claude.ai/install.sh) bootstrap script
- Binary is symlinked to `/usr/local/bin/claude`
- Build provenance attestations are generated for supply chain security

## Checking the Claude Version in an Image

There are three ways to find out which Claude CLI version an image (or tag) contains:

**1. Without pulling the image**, via the `org.opencontainers.image.version` OCI label:

```bash
docker buildx imagetools inspect ghcr.io/ablack94/docker-claude:stable \
  --format '{{ index .Image.Config.Labels "org.opencontainers.image.version" }}'
```

(`skopeo inspect docker://ghcr.io/ablack94/docker-claude:stable | jq -r '.Labels."org.opencontainers.image.version"'` is equivalent if you prefer skopeo.)

> Note: this label is only populated with a real semver on images built after the versioning changes described here. Older `:stable` publishes carry the literal string `stable` in this label instead.

**2. From the image filesystem**, via `/etc/claude-version` (a bare semver + trailing newline, written at build time):

```bash
docker run --rm ghcr.io/ablack94/docker-claude:stable cat /etc/claude-version
```

This file is also available to `COPY --from=` consumers — copy it alongside the binary if you want the version on hand at runtime without invoking `claude --version`:

```dockerfile
COPY --from=claude /etc/claude-version /etc/claude-version
```

**3. By running the binary**:

```bash
docker run --rm ghcr.io/ablack94/docker-claude:stable claude --version
```

## Build from Source

```bash
git clone https://github.com/ablack94/docker-claude.git
cd docker-claude
docker build -t docker-claude .
```

To build a specific version:

```bash
docker build --build-arg CLAUDE_VERSION=1.2.3 -t docker-claude:1.2.3 .
```

## License

MIT
