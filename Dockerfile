FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/ablack94/docker-claude"
LABEL org.opencontainers.image.description="Minimal Docker image containing the Claude CLI"
LABEL org.opencontainers.image.licenses="MIT"

ARG CLAUDE_VERSION=stable

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://claude.ai/install.sh | bash -s -- "$CLAUDE_VERSION" \
    && ln -s /root/.local/bin/claude /usr/local/bin/claude

ENTRYPOINT ["claude"]
