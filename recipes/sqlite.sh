#!/bin/sh
# sqlite.sh — cross-build libsqlite3.a for one target.
#
# The one common Tier-3 contrib dependency (asks/contrib-cross-compile.md in
# the aether repo): contrib.sqlite needs sqlite3, which is absent from zig's
# bundled targets AND from the FreeBSD base.txz. Opt-in via CB_LIBS (not in the
# default set) — enable with CB_LIBS="... sqlite" ./provision.sh <triple>.
#
# The autoconf amalgamation tarball is a single sqlite3.c + sqlite3.h, so there
# is NO ./configure — we compile the amalgamation directly with the target's
# pinned `zig cc` wrapper and archive with the wrapper's `ar` (zig ar). This
# mirrors what aether's contrib_build.sh does for the module .c that links this.

build_sqlite() {
    _t=$1; _wd=$2
    _extra=$(target_extra_cflags "$_t")   # --sysroot=... for freebsd, "" otherwise

    _src=$(fetch_verify sqlite "$_t")
    [ -f "$_src/sqlite3.c" ] || die "sqlite: amalgamation sqlite3.c not found in $_src"

    # Recommended build-time options for an embeddable static lib. THREADSAFE=1
    # is the default the contrib bridge expects; the FTS/JSON options match a
    # typical distro libsqlite3 so an app doesn't hit a missing-feature surprise
    # after cross-shipping.
    _opts="-DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_JSON1 \
           -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_DBSTAT_VTAB"

    log "sqlite: compile amalgamation (zig cc -c)"
    # shellcheck disable=SC2086
    ( cd "$_src" \
      && "$_wd/cc" -O2 -fPIC $_extra $_opts -c sqlite3.c -o sqlite3.o \
         >"$WORK/sqlite-$_t-compile.log" 2>&1 \
      || die "sqlite compile failed for $_t (see $WORK/sqlite-$_t-compile.log)" )

    log "sqlite: archive libsqlite3.a (zig ar)"
    ( cd "$_src" \
      && "$_wd/ar" rcs libsqlite3.a sqlite3.o \
      || die "sqlite archive failed for $_t" )

    _lib="$_src/libsqlite3.a"
    [ -f "$_lib" ] || die "sqlite: libsqlite3.a not produced"
    stage_lib     "$_t" "$_lib"
    stage_headers "$_t" "$_src/sqlite3.h" "$_src/sqlite3ext.h"
    stage_license "$_t" sqlite "$_src/LICENSE.md"
    assert_arch   "$_t" "$_lib"
    log "sqlite: staged for $_t ✓"
}
