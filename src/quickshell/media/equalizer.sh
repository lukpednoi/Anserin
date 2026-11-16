#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh" || exit 1
exec python3 "$(dirname "${BASH_SOURCE[0]}")/equalizer.py" "$@"
