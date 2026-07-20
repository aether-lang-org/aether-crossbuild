#!/bin/sh
# lua.sh — stage Lua 5.4 headers for one target (HEADER-ONLY).
#
# contrib/host/lua loads liblua via dlopen at RUNTIME ("dlopen, not -llua") and
# resolves every C-API function with dlsym — but it #includes lua.h/lauxlib.h/
# lualib.h at COMPILE time for the type/macro definitions. So cross-building the
# host_lua archive needs only the Lua headers in the sysroot; NO cross-built
# liblua.a is required (the target dlopen's its own liblua at runtime).
#
# Opt-in via CB_LIBS (not in the default set): CB_LIBS="... lua" ./provision.sh.
# Lua's headers are self-contained (luaconf.h auto-detects the platform via its
# own #ifdefs) and arch-independent, so a single fetch stages for any target.

build_lua() {
    _t=$1; _wd=$2   # _wd unused: header-only, nothing compiled

    _src=$(fetch_verify lua "$_t")
    for _h in lua.h luaconf.h lauxlib.h lualib.h; do
        [ -f "$_src/src/$_h" ] || die "lua: header src/$_h not found in $_src"
    done

    log "lua: stage headers (header-only — liblua is dlopen'd at runtime)"
    stage_headers "$_t" \
        "$_src/src/lua.h" "$_src/src/luaconf.h" \
        "$_src/src/lauxlib.h" "$_src/src/lualib.h"
    stage_license "$_t" lua "$_src/doc/readme.html"   # Lua license text lives here
    log "lua: staged for $_t ✓"
}
