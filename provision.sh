#!/bin/sh
# provision.sh — cross-build all four external deps for one target (or --all),
# staging a self-contained sysroot under ./sysroots/<triple>/.
#
#   ./provision.sh aarch64-macos          # one target
#   ./provision.sh --all                  # every target in the matrix
#   ./provision.sh --list                 # print the matrix and exit
#   CB_LIBS="pcre2 openssl" ./provision.sh aarch64-macos   # subset of libs
#
# Run occasionally, by hand, on trusted dev infrastructure. Produces artifacts
# that are git-ignored and never published (see WHY-NOT-PUBLISHED.md).

set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$ROOT/recipes/common.sh"
. "$ROOT/recipes/zlib.sh"
. "$ROOT/recipes/pcre2.sh"
. "$ROOT/recipes/nghttp2.sh"
. "$ROOT/recipes/openssl.sh"
. "$ROOT/recipes/sqlite.sh"
. "$ROOT/recipes/lua.sh"
. "$ROOT/recipes/duktape.sh"

# The full matrix (Tier A turnkey — macos/linux/windows; Tier B — freebsd).
MATRIX="x86_64-macos aarch64-macos \
        x86_64-linux-gnu aarch64-linux-gnu \
        x86_64-linux-musl aarch64-linux-musl \
        x86_64-windows aarch64-windows \
        x86_64-freebsd aarch64-freebsd"

# Libraries to build, in dependency-free order (openssl last: it's the slow one).
# NB: named CB_LIBS, not LIBS — autoconf treats $LIBS as magic and would leak it
# into configure's link probe (`cc conftest.c <name>`), breaking the build.
: "${CB_LIBS:=zlib pcre2 nghttp2 openssl}"


# Fetch-hint decomposition of a (possibly versioned) freebsd triple:
#   x86_64-freebsd15 -> cpu=x86_64 ver=15 ;  x86_64-freebsd -> cpu=x86_64 ver=""
fbsd_cpu() { echo "${1%%-freebsd*}"; }
fbsd_ver() { case "$1" in *-freebsd[0-9]*) echo "${1##*-freebsd}" ;; *) echo "" ;; esac; }

need curl; need tar; need make; need awk; need sha256sum

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

provision_one() {
    _t=$1
    _zt=$(map_zig_target "$_t")            # validates the triple
    printf '\n\033[1m== %s  (zig -target %s)\033[0m\n' "$_t" "$_zt" >&2

    if is_freebsd "$_t" && [ ! -d "$BASES/$_t" ]; then
        die "freebsd target needs a base sysroot: run ./scripts/fetch-freebsd-base.sh $(fbsd_cpu "$_t") $(fbsd_ver "$_t")"
    fi

    # FreeBSD wrappers get the base sysroot so their cc adds the link recipe
    # (CRT + libc.so.7) on exe links / configure probes. Tier A: no base arg.
    _wbase=""
    if is_freebsd "$_t"; then _wbase="$BASES/$_t"; fi
    _wd=$(setup_zig_wrappers "$_zt" "$_wbase")   # cc/ar/ranlib pinned to this target
    for _lib in $CB_LIBS; do
        case "$_lib" in
            zlib)    build_zlib    "$_t" "$_wd" ;;
            pcre2)   build_pcre2   "$_t" "$_wd" ;;
            nghttp2) build_nghttp2 "$_t" "$_wd" ;;
            openssl) build_openssl "$_t" "$_wd" ;;
            sqlite)  build_sqlite  "$_t" "$_wd" ;;
            lua)     build_lua     "$_t" "$_wd" ;;
            duktape) build_duktape "$_t" "$_wd" ;;
            *) die "unknown lib in CB_LIBS: $_lib" ;;
        esac
    done

    # Drop a manifest so a consumer (ae build --sysroot) and a human can see what's here.
    _mf="$(sysroot_dir "$_t")/MANIFEST.txt"
    {
        echo "# aether-crossbuild sysroot: $_t"
        echo "# generated from deps.lock — DO NOT PUBLISH (see WHY-NOT-PUBLISHED.md)"
        for _lib in $CB_LIBS; do printf '%s %s\n' "$_lib" "$(lock_field "$_lib" version)"; done
    } > "$_mf"
    printf '\033[32m✓ %s ready:\033[0m %s\n' "$_t" "$(sysroot_dir "$_t")" >&2
}

case "${1:-}" in
    ""|-h|--help) usage 0 ;;
    --list) printf '%s\n' $MATRIX; exit 0 ;;
    --all)
        for t in $MATRIX; do
            # skip freebsd targets that have no base yet, with a clear note
            if is_freebsd "$t" && [ ! -d "$BASES/$t" ]; then
                log "skip $t (no base sysroot — run scripts/fetch-freebsd-base.sh $(fbsd_cpu "$t") $(fbsd_ver "$t"))"
                continue
            fi
            provision_one "$t"
        done
        ;;
    *) provision_one "$1" ;;
esac
