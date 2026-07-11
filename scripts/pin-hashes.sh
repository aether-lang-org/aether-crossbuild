#!/bin/sh
# pin-hashes.sh — download every deps.lock URL and print its real sha256, so you
# can replace the PIN_ME placeholders. Run once after picking versions; paste the
# results into deps.lock. Keeps the lock honest and both maintainers reproducible.
#
#   ./scripts/pin-hashes.sh            # print name + sha for every entry
#   ./scripts/pin-hashes.sh --rewrite  # rewrite deps.lock in place (backs up .bak)

set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LOCK="$ROOT/deps.lock"
DL="$ROOT/work/downloads"; mkdir -p "$DL"
rewrite=0; [ "${1:-}" = "--rewrite" ] && rewrite=1

tmp=$(mktemp)
# Walk each non-comment, non-blank line: name version url sha
while IFS= read -r line; do
    case "$line" in ''|\#*) printf '%s\n' "$line" >> "$tmp"; continue ;; esac
    name=$(printf '%s' "$line" | awk '{print $1}')
    ver=$(printf '%s' "$line" | awk '{print $2}')
    url=$(printf '%s' "$line" | awk '{print $3}')
    f="$DL/$(basename "$url")"
    [ -f "$f" ] || { echo "fetch $name" >&2; curl -fsSL "$url" -o "$f"; }
    sha=$(sha256sum "$f" | awk '{print $1}')
    printf '%-22s %-8s %s  %s\n' "$name" "$ver" "$url" "$sha"
    printf '%-22s %-8s %s  %s\n' "$name" "$ver" "$url" "$sha" >> "$tmp"
done < "$LOCK"

if [ "$rewrite" = 1 ]; then
    cp "$LOCK" "$LOCK.bak"
    mv "$tmp" "$LOCK"
    echo "deps.lock rewritten (backup: deps.lock.bak)" >&2
else
    rm -f "$tmp"
    echo "" >&2
    echo "(dry run — paste the sha column into deps.lock, or re-run with --rewrite)" >&2
fi
