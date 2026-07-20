#!/bin/sh
# duktape.sh — stage Duktape headers for one target (HEADER-ONLY).
#
# contrib/host/duktape loads libduktape via dlopen at RUNTIME ("dlopen, not
# -lduktape") and dlsym's every Duktape C-API symbol — but it #includes
# duktape.h at COMPILE time for the type/macro definitions. So cross-building
# the host_duktape archive needs only the Duktape headers (duktape.h +
# duk_config.h) in the sysroot; NO cross-built libduktape is required.
#
# Opt-in via CB_LIBS (not in the default set): CB_LIBS="... duktape".
# duk_config.h auto-detects the platform via its own #ifdefs, so the prepared
# distribution's headers are arch-independent — a single fetch stages any target.

build_duktape() {
    _t=$1; _wd=$2   # _wd unused: header-only

    _src=$(fetch_verify duktape "$_t")
    for _h in duktape.h duk_config.h; do
        [ -f "$_src/src/$_h" ] || die "duktape: header src/$_h not found in $_src"
    done

    log "duktape: stage headers (header-only — libduktape is dlopen'd at runtime)"
    stage_headers "$_t" "$_src/src/duktape.h" "$_src/src/duk_config.h"
    stage_license "$_t" duktape "$_src/LICENSE.txt"
    log "duktape: staged for $_t ✓"
}
