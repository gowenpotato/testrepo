#!/usr/bin/env bash
set -euo pipefail

tmpdir=$(mktemp -d)
lockfile="/tmp/myscript.lock"

[[ -f "$lockfile" ]] && { echo "already running" >&2; exit 1; }
touch "$lockfile"

cleanup() {
    local exit_code=$?
    rm -f "$lockfile"
    rm -rf "$tmpdir"
    [[ $exit_code -ne 0 ]] && echo "exited with code $exit_code" >&2
    exit $exit_code
}
trap cleanup EXIT

main() {
    # your code here
}

main "$@"
