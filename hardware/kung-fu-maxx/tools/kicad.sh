#!/bin/sh
set -eu
state="${TMPDIR:-/tmp}/maxx-kicad"
mkdir -p "$state/config" "$state/cache" "$state/data"
export XDG_CONFIG_HOME="$state/config" XDG_CACHE_HOME="$state/cache" XDG_DATA_HOME="$state/data"
exec kicad-cli "$@"
