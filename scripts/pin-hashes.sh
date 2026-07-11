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
failures=0
# Walk each non-comment, non-blank line: name version url sha
# One dead URL must NOT discard the hashes we already computed — a failed fetch
# keeps that entry's existing sha field (usually PIN_ME) and continues.
while IFS= read -r line; do
    case "$line" in ''|\#*) printf '%s\n' "$line" >> "$tmp"; continue ;; esac
    name=$(printf '%s' "$line" | awk '{print $1}')
    ver=$(printf '%s' "$line" | awk '{print $2}')
    url=$(printf '%s' "$line" | awk '{print $3}')
    oldsha=$(printf '%s' "$line" | awk '{print $4}')
    # Cache key must be collision-safe: FreeBSD amd64 and arm64 are both named
    # base.txz but are different files. Prefix the entry NAME (unique per line).
    f="$DL/$name-$(basename "$url")"
    if [ ! -f "$f" ]; then
        echo "fetch $name" >&2
        if ! curl -fsSL --max-time 300 "$url" -o "$f"; then
            echo "  WARNING: fetch failed for '$name' ($url) — keeping '$oldsha'" >&2
            rm -f "$f"
            failures=$((failures + 1))
            printf '%-22s %-8s %s  %s\n' "$name" "$ver" "$url" "$oldsha" >> "$tmp"
            continue
        fi
    fi
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

if [ "$failures" -gt 0 ]; then
    echo "" >&2
    echo "$failures URL(s) failed — those entries still say PIN_ME. Fix the URL in" >&2
    echo "deps.lock and re-run; the successful hashes above are preserved." >&2
fi
