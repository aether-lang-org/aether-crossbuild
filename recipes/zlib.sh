#!/bin/sh
# zlib.sh — cross-build libz.a for one target.
# zlib's configure is NOT autoconf: it honours CC/AR/RANLIB from the environment
# and cross-targets via those (no --host). We build the static lib only.
# Pattern is standard; validate on first real run.

build_zlib() {
    _t=$1; _wd=$2
    _extra=$(target_extra_cflags "$_t")

    _src=$(fetch_verify zlib "$_t")
    log "zlib: configure --static"
    # zlib's configure is not autoconf; it reads CC/AR/RANLIB/CFLAGS from env.
    run_configure "$_wd" "$_extra" "$_src" -- \
        --static --prefix="$WORK/zlib-$_t-prefix" \
        >"$WORK/zlib-$_t-configure.log" 2>&1 \
      || die "zlib configure failed for $_t (see $WORK/zlib-$_t-configure.log)"

    log "zlib: make libz.a"
    ( cd "$_src" \
      && make -j"$(nproc 2>/dev/null || echo 4)" libz.a \
         >"$WORK/zlib-$_t-make.log" 2>&1 \
      || die "zlib make failed for $_t (see $WORK/zlib-$_t-make.log)" )

    _lib="$_src/libz.a"
    [ -f "$_lib" ] || die "zlib: libz.a not produced"
    stage_lib     "$_t" "$_lib"
    stage_headers "$_t" "$_src/zlib.h" "$_src/zconf.h"
    stage_license "$_t" zlib "$_src/LICENSE"
    assert_arch   "$_t" "$_lib"
    log "zlib: staged for $_t ✓"
}
