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
| `stable` | Latest build from `main` branch (default) |
| `x.y.z` | Pinned to a specific Claude CLI version (e.g. `1.2.3`) |
| `x.y` | Latest patch for a given minor version |
| `x` | Latest minor/patch for a given major version |

## How It Works

- Installs the Claude CLI via the official [`claude.ai/install.sh`](https://claude.ai/install.sh) bootstrap script
- Binary is symlinked to `/usr/local/bin/claude`
- Build provenance attestations are generated for supply chain security

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
