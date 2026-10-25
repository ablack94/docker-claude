#!/usr/bin/env bash
# Decide what the publish workflow needs to do, and emit it as GitHub Actions outputs.
#
# Inputs (env):
#   EVENT_NAME, REF, REF_NAME        - from the github context
#   INPUT_VERSION, INPUT_TAG         - workflow_dispatch inputs
#   IMAGE                            - e.g. ghcr.io/ablack94/docker-claude
#   RELEASES_URL                     - release metadata bucket used by install.sh
#   GITHUB_OUTPUT                    - output file (defaults to stdout for local runs)
#
# Outputs:
#   matrix   - JSON array of {version, action, tags}, where action is "build" or
#              "retag" and tags is a comma-separated list of full image refs.
#              Versions that need nothing are left out.
#   stable   - resolved stable version (channel events only)
#   latest   - resolved latest version (channel events only)
#   channels - "true" when this run tracks the stable/latest channels
set -euo pipefail

: "${IMAGE:?}" "${RELEASES_URL:?}" "${EVENT_NAME:?}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+'

resolve() {
  local requested="$1" version
  if [[ "$requested" == "stable" || "$requested" == "latest" ]]; then
    version="$(curl -fsSL "${RELEASES_URL}/${requested}" | tr -d '[:space:]')"
    echo "Resolved channel '$requested' to '$version'" >&2
  else
    version="$requested"
  fi
  if [[ ! "$version" =~ $SEMVER_RE ]]; then
    echo "::error::Resolved Claude version '$version' is not a valid semver" >&2
    return 1
  fi
  echo "$version"
}

core()  { grep -oE "$SEMVER_RE" <<<"$1"; }
minor() { core "$1" | cut -d. -f1-2; }
major() { core "$1" | cut -d. -f1; }

# Manifest digest of a published tag, or empty if the tag doesn't exist.
digest() {
  docker buildx imagetools inspect "$1" --format '{{json .Manifest}}' 2>/dev/null \
    | jq -r '.digest // empty' 2>/dev/null || true
}

entries=()

# add_entry VERSION ACTION TAG...
add_entry() {
  local version="$1" action="$2"; shift 2
  local refs
  refs="$(printf "${IMAGE}:%s," "$@")"
  entries+=("$(jq -cn --arg v "$version" --arg a "$action" --arg t "${refs%,}" \
    '{version: $v, action: $a, tags: $t}')")
  echo "Plan: $version -> $action ($*)" >&2
}

channels=false

if [[ "$EVENT_NAME" == "workflow_dispatch" ]]; then
  version="$(resolve "${INPUT_VERSION:?}")"
  add_entry "$version" build "${INPUT_TAG:?}"

elif [[ "${REF:-}" == refs/tags/v* ]]; then
  version="$(resolve "${REF_NAME#v}")"
  add_entry "$version" build "$(core "$version")" "$(minor "$version")" "$(major "$version")"

else
  # Push to main or scheduled poll: track both release channels.
  channels=true
  stable="$(resolve stable)"
  latest="$(resolve latest)"
  echo "stable=$stable" >> "$GITHUB_OUTPUT"
  echo "latest=$latest" >> "$GITHUB_OUTPUT"

  # The rolling X.Y / X tags belong to the highest of the two versions, unless
  # the other version is on a different X.Y / X line.
  max="$(printf '%s\n%s\n' "$stable" "$latest" | sort -V | tail -n1)"

  for version in $(printf '%s\n%s\n' "$stable" "$latest" | sort -uV); do
    tags=()
    [[ "$version" == "$stable" ]] && tags+=(stable)
    [[ "$version" == "$latest" ]] && tags+=(latest)
    tags+=("$version")
    if [[ "$version" == "$max" || "$(minor "$max")" != "$(minor "$version")" ]]; then
      tags+=("$(minor "$version")")
    fi
    if [[ "$version" == "$max" || "$(major "$max")" != "$(major "$version")" ]]; then
      tags+=("$(major "$version")")
    fi

    # A push to main may have changed the Dockerfile, so always rebuild.
    if [[ "$EVENT_NAME" == "push" ]]; then
      add_entry "$version" build "${tags[@]}"
      continue
    fi

    # Otherwise never rebuild a published X.Y.Z (keeps it immutable): just
    # point any stale tags at it.
    want="$(digest "${IMAGE}:${version}")"
    if [[ -z "$want" ]]; then
      add_entry "$version" build "${tags[@]}"
      continue
    fi
    stale=false
    for tag in "${tags[@]}"; do
      [[ "$(digest "${IMAGE}:${tag}")" == "$want" ]] || stale=true
    done
    if [[ "$stale" == true ]]; then
      add_entry "$version" retag "${tags[@]}"
    else
      echo "Plan: $version -> up to date (${tags[*]})" >&2
    fi
  done
fi

echo "channels=$channels" >> "$GITHUB_OUTPUT"
echo "matrix=$(printf '%s\n' "${entries[@]}" | jq -cs '.')" >> "$GITHUB_OUTPUT"
