#!/bin/sh
# openssl.sh — cross-build libssl.a + libcrypto.a for one target.
# VALIDATED: aarch64-macos on Linux x86_64 host produced Mach-O arm64 libs.
#
# openssl is the hard one: its own ./Configure with a per-target name (NOT
# autoconf), and its macOS path pulls in an Apple-framework header. See below.

build_openssl() {
    _t=$1; _wd=$2
    _osslt=$(map_openssl_target "$_t")
    _extra=$(target_extra_cflags "$_t")

    # --- the Apple-SDK avoidance, load-bearing ---------------------------------
    # openssl's macOS build #includes <CommonCrypto/CommonCryptoError.h>, an
    # Apple-framework header zig cc does NOT ship. -DOPENSSL_NO_APPLE_CRYPTO_RANDOM
    # makes openssl use getentropy/arc4random from libSystem instead — no Apple
    # framework surface. This keeps the "never touch Apple SDK" policy intact
    # (see WHY-NOT-PUBLISHED.md). DO NOT remove this to "get native RNG".
    _osslflags=""
    case "$_t" in *-macos) _osslflags="-DOPENSSL_NO_APPLE_CRYPTO_RANDOM" ;; esac

    _src=$(fetch_verify openssl "$_t")
    log "openssl: Configure $_osslt (no-shared, libs only)"
    ( cd "$_src" \
      && PATH="$_wd:$PATH" CC="$_wd/cc" \
         ./Configure "$_osslt" \
             no-shared no-tests no-apps no-docs no-legacy \
             ${_extra} ${_osslflags} \
             >"$WORK/openssl-$_t-configure.log" 2>&1 \
      || die "openssl Configure failed for $_t (see $WORK/openssl-$_t-configure.log)" )

    log "openssl: make build_libs (slow — this dominates the run)"
    ( cd "$_src" \
      && PATH="$_wd:$PATH" \
         make -j"$(nproc 2>/dev/null || echo 4)" build_libs \
         >"$WORK/openssl-$_t-make.log" 2>&1 \
      || die "openssl make failed for $_t (see $WORK/openssl-$_t-make.log)" )

    [ -f "$_src/libcrypto.a" ] || die "openssl: libcrypto.a not produced"
    [ -f "$_src/libssl.a" ]    || die "openssl: libssl.a not produced"
    stage_lib     "$_t" "$_src/libssl.a" "$_src/libcrypto.a"
    stage_headers "$_t" "$_src/include/openssl"   # -> include/openssl/*
    # openssl generizes some headers into include/openssl at configure time; the
    # opensslconf.h lands there too. Ensure the parent 'openssl/' dir shape.
    _incdst="$(sysroot_dir "$_t")/include/openssl"
    mkdir -p "$_incdst"
    cp -Rf "$_src/include/openssl/." "$_incdst/" 2>/dev/null || true
    stage_license "$_t" openssl "$_src/LICENSE.txt"
    assert_arch   "$_t" "$_src/libcrypto.a"
    log "openssl: staged for $_t ✓"
}
