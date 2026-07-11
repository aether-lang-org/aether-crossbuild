#!/bin/sh
# pcre2.sh — cross-build libpcre2-8.a for one target.
# VALIDATED: aarch64-macos on Linux x86_64 host produced a Mach-O arm64 .a.
#
# Standard autoconf cross: ./configure --host=<autoconf-host> CC="<zig cc wrapper>".
# We build only the static 8-bit lib (std.regex links -lpcre2-8).

build_pcre2() {
    _t=$1; _wd=$2                       # target triple, wrapper dir
    _host=$(map_autoconf_host "$_t")
    _extra=$(target_extra_cflags "$_t") # "" or --sysroot=... for freebsd

    _src=$(fetch_verify pcre2)
    log "pcre2: configure --host=$_host"
    run_configure "$_wd" "$_extra" "$_src" -- \
        --host="$_host" \
        --disable-shared --enable-static \
        --enable-pcre2-8 --disable-pcre2-16 --disable-pcre2-32 \
        --disable-pcre2grep-libz --disable-pcre2grep-libbz2 \
        >"$WORK/pcre2-$_t-configure.log" 2>&1 \
      || die "pcre2 configure failed for $_t (see $WORK/pcre2-$_t-configure.log)"

    log "pcre2: make libpcre2-8.la"
    ( cd "$_src" \
      && make -j"$(nproc 2>/dev/null || echo 4)" libpcre2-8.la \
         >"$WORK/pcre2-$_t-make.log" 2>&1 \
      || die "pcre2 make failed for $_t (see $WORK/pcre2-$_t-make.log)" )

    _lib="$_src/.libs/libpcre2-8.a"
    [ -f "$_lib" ] || die "pcre2: expected $_lib not produced"
    stage_lib     "$_t" "$_lib"
    stage_headers "$_t" "$_src/src/pcre2.h"
    stage_license "$_t" pcre2 "$_src/LICENCE" "$_src/AUTHORS"
    assert_arch   "$_t" "$_lib"
    log "pcre2: staged for $_t ✓"
}
