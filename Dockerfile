FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/ablack94/docker-claude"
LABEL org.opencontainers.image.description="Minimal Docker image containing the Claude CLI"
LABEL org.opencontainers.image.licenses="MIT"

ARG CLAUDE_VERSION=stable

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://claude.ai/install.sh | bash -s -- "$CLAUDE_VERSION" \
    && ln -s /root/.local/bin/claude /usr/local/bin/claude \
    # Record the installed version so consumers can read it without executing the binary.
    && INSTALLED_VERSION="$(/usr/local/bin/claude --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)" \
    && if [ -z "$INSTALLED_VERSION" ]; then echo "ERROR: could not parse a semver from 'claude --version' output" >&2; exit 1; fi \
    && echo "$INSTALLED_VERSION" > /etc/claude-version \
    # If CLAUDE_VERSION pins a concrete semver, fail the build unless the installed version matches.
    && if echo "$CLAUDE_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' && [ "$INSTALLED_VERSION" != "$CLAUDE_VERSION" ]; then \
         echo "ERROR: requested CLAUDE_VERSION=$CLAUDE_VERSION but installed claude reports version $INSTALLED_VERSION" >&2; \
         exit 1; \
       fi

ENTRYPOINT ["claude"]
