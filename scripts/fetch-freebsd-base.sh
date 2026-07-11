#!/bin/sh
# fetch-freebsd-base.sh — populate a FreeBSD base sysroot (headers + libc) under
# ./bases/<cpu>-freebsd/, needed because zig cc does NOT bundle a FreeBSD libc.
#
#   ./scripts/fetch-freebsd-base.sh x86_64
#   ./scripts/fetch-freebsd-base.sh aarch64
#
# FreeBSD base is BSD-licensed and freely redistributable — this is the ONE tier
# with a stored blob, and it's the safe one (no Apple restriction). We still keep
# it git-ignored for repo hygiene, not for licensing.

set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cpu=${1:-}
case "$cpu" in
    x86_64|amd64) cpu=x86_64; key=freebsd-base-x86_64; triple=x86_64-freebsd ;;
    aarch64|arm64) cpu=aarch64; key=freebsd-base-aarch64; triple=aarch64-freebsd ;;
    *) echo "usage: $0 <x86_64|aarch64>" >&2; exit 2 ;;
esac

url=$(grep -E "^$key[[:space:]]" "$ROOT/deps.lock" | awk '{print $3}')
sha=$(grep -E "^$key[[:space:]]" "$ROOT/deps.lock" | awk '{print $4}')
[ -n "$url" ] || { echo "no $key entry in deps.lock" >&2; exit 1; }

DL="$ROOT/work/downloads"; mkdir -p "$DL"
base="$ROOT/bases/$triple"
tar="$DL/$(basename "$url")-$cpu"

if [ ! -f "$tar" ]; then
    echo "fetch FreeBSD base <- $url" >&2
    curl -fsSL "$url" -o "$tar"
fi
if [ "$sha" != "PIN_ME" ]; then
    got=$(sha256sum "$tar" | awk '{print $1}')
    [ "$got" = "$sha" ] || { echo "base checksum mismatch: $got != $sha" >&2; exit 1; }
fi

# base.txz is a full root filesystem image; we only need usr/include + usr/lib +
# lib for linking. Extract just those to keep the sysroot lean.
rm -rf "$base"; mkdir -p "$base"
echo "extract usr/include, usr/lib, lib -> $base" >&2
tar xf "$tar" -C "$base" ./usr/include ./usr/lib ./lib 2>/dev/null \
    || tar xf "$tar" -C "$base" usr/include usr/lib lib 2>/dev/null \
    || { echo "extract failed — is this a base.txz?" >&2; exit 1; }

echo "FreeBSD base ready: $base" >&2
echo "now run: ./provision.sh $triple" >&2
