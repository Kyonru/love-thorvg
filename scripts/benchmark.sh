#!/bin/sh
set -eu

repository=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
love_binary=${LOVE_BIN:-love}

if [ -z "${LOVE_BIN:-}" ] && [ -x /Applications/love.app/Contents/MacOS/love ]; then
  love_binary=/Applications/love.app/Contents/MacOS/love
fi

cd "$repository/benchmarks/render"
exec "$love_binary" .
