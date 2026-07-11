#!/bin/sh
# nghttp2.sh — cross-build libnghttp2.a for one target.
# Standard autoconf cross, but with --enable-lib-only so we skip the apps/tools
# (which would pull in more deps). std.http links -lnghttp2.
# Pattern is standard; validate on first real run.

build_nghttp2() {
    _t=$1; _wd=$2
    _host=$(map_autoconf_host "$_t")
    _extra=$(target_extra_cflags "$_t")

    _src=$(fetch_verify nghttp2 "$_t")
    log "nghttp2: configure --host=$_host --enable-lib-only"
    run_configure "$_wd" "$_extra" "$_src" -- \
        --host="$_host" \
        --enable-lib-only \
        --disable-shared --enable-static \
        --without-libxml2 --without-jansson --without-openssl \
        >"$WORK/nghttp2-$_t-configure.log" 2>&1 \
      || die "nghttp2 configure failed for $_t (see $WORK/nghttp2-$_t-configure.log)"

    log "nghttp2: make"
    ( cd "$_src/lib" \
      && make -j"$(nproc 2>/dev/null || echo 4)" \
         >"$WORK/nghttp2-$_t-make.log" 2>&1 \
      || die "nghttp2 make failed for $_t (see $WORK/nghttp2-$_t-make.log)" )

    _lib="$_src/lib/.libs/libnghttp2.a"
    [ -f "$_lib" ] || die "nghttp2: libnghttp2.a not produced"
    stage_lib     "$_t" "$_lib"
    stage_headers "$_t" "$_src/lib/includes/nghttp2"   # -> include/nghttp2/*
    stage_license "$_t" nghttp2 "$_src/COPYING"
    assert_arch   "$_t" "$_lib"
    log "nghttp2: staged for $_t ✓"
}
