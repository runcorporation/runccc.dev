#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# It downloads the release built for this machine, 
# It covers Linux and macOS; Windows builds are on the releases page.
#
# Settings, as environment variables:
#   CCC_INSTALL_DIR  where to put ccc (default: ~/.local/bin)
#   CCC_VERSION      the release tag to install, such as v1.7.0 (default: the latest)
#   CCC_OS, CCC_ARCH skip detecting the platform (linux or macos; x86_64,
#                    aarch64, armv7, i686 or riscv64)
#
# Run it again to update ccc.

set -euo pipefail

say() { printf 'ccc: %s\n' "$*"; }
fail() { printf 'ccc: %s\n' "$*" >&2; exit 1; }

# Everything runs from main, so a `curl | bash` has read the whole script
# before any of it runs.
main() {
  local repo="https://github.com/colwill/ccc"
  local os arch asset url

  case "${CCC_OS:-$(uname -s)}" in
    Linux | linux) os=linux ;;
    Darwin | macos) os=macos ;;
    *) fail "this installer covers Linux and macOS. Windows builds are at $repo/releases/latest, or build it from source: $repo#readme" ;;
  esac
  case "${CCC_ARCH:-$(uname -m)}" in
    x86_64 | amd64) arch=x86_64 ;;
    aarch64 | arm64) arch=aarch64 ;;
    armv7 | armv7l | armv6l | armhf) arch=armv7 ;;
    i386 | i486 | i586 | i686) arch=i686 ;;
    riscv64) arch=riscv64 ;;
    *) fail "there's no release built for ${CCC_ARCH:-$(uname -m)}: build it from source instead: $repo#readme" ;;
  esac
  asset="ccc-$os-$arch"

  if [ -n "${CCC_VERSION:-}" ]; then
    url="$repo/releases/download/$CCC_VERSION/$asset"
  else
    url="$repo/releases/latest/download/$asset"
  fi

  # tmp isn't local: the EXIT trap reads it after main has returned
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  say "downloading $asset from $url"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 2 -o "$tmp/ccc" "$url" || fail "couldn't download $url: is there a release built for $os/$arch?"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp/ccc" "$url" || fail "couldn't download $url: is there a release built for $os/$arch?"
  else
    fail "curl or wget is required: install one, then run this again"
  fi
  chmod +x "$tmp/ccc"

  # a wrong build, or an error page saved as the binary, stops here, before
  # anything on this machine changes
  "$tmp/ccc" --version >/dev/null 2>&1 || fail "the downloaded ccc doesn't run on this machine ($os/$arch)"

  if [ -n "${CCC_INSTALL_DIR:-}" ]; then
    "$tmp/ccc" install --force --dir "$CCC_INSTALL_DIR"
  else
    "$tmp/ccc" install --force
  fi

  cat <<EOF

$("$tmp/ccc" --version) is ready. Next, in a repository:
  ccc init    map the project, into .ccc/map.json
  ccc run     the MCP server and insights, at http://127.0.0.1:6767/insights

Encrypted replays for your team: https://teams.runccc.dev
EOF
}

main "$@"
