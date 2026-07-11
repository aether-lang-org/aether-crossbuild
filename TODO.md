# TODO

Extension work for aether-crossbuild. The script is structured so adding a
target is a few `case`-arms in `recipes/common.sh` (`map_zig_target`,
`map_autoconf_host`, `map_openssl_target`, `target_extra_cflags`) plus a `MATRIX`
entry — not a rewrite. Add **validated** targets only; a speculative row that
nobody has run rots into a broken row. Prove each new target builds at least one
lib before committing it to `MATRIX`.

## Priority: Windows (x86_64 + aarch64)

The one genuine gap. `zig cc` bundles a full Windows target (MinGW-w64 CRT), so
it's turnkey compiler-side — no sysroot — and "deliver a Windows `.exe` from a
Linux agent" is a headline use case (Aether's own CI matrix gates on Windows).

Not a one-liner, though — the four deps map differently on Windows:

- [ ] **`map_zig_target`**: `x86_64-windows` → `x86_64-windows-gnu`,
      `aarch64-windows` → `aarch64-windows-gnu`.
- [ ] **`map_autoconf_host`** (zlib CHOST / pcre2 / nghttp2): `x86_64-w64-mingw32`,
      `aarch64-w64-mingw32`.
- [ ] **`map_openssl_target`**: `mingw64` (x86_64) / `mingw` — openssl's Windows
      Configure targets, not the `darwin*`/`linux-*` ones. Watch for Win32 API
      calls in openssl's build; may need `no-asm` or extra flags on aarch64.
- [ ] **Staging nuance**: Windows import/static libs. We build `--disable-shared`
      so it stays `.a` (MinGW archives), but confirm the linker later wants
      `libfoo.a` not `foo.lib`, and that headers land the same way.
- [ ] **`assert_arch`**: already has a `*windows*:*COFF*|*windows*:*PE32*` arm;
      verify `file(1)` reports COFF for a MinGW `.a` member.
- [ ] **Validate**: cross-build at least pcre2 + openssl to `x86_64-windows` on a
      Linux box and confirm `Mach-O`→COFF/PE members, the way mac was proven.
- [ ] Add both to `MATRIX` in `provision.sh` once green.

## On demand only (don't add speculatively)

`zig cc` can target far more than we should carry. Add these when a real consumer
asks, using the existing recipes as the template:

- [ ] **32-bit ARM Linux** (`arm-linux-gnueabihf`, `arm-linux-musl`) — Raspberry
      Pi / embedded class. musl variant gives a static portable binary.
- [ ] **riscv64-linux** (gnu + musl) — turnkey compiler-side; openssl builds but
      is the usual per-arch adventure.
- [ ] **ppc64le / s390x-linux** — only for enterprise/mainframe asks. Expect
      openssl per-arch friction.
- [ ] **NetBSD / OpenBSD** — same shape as FreeBSD: no bundled zig libc, so each
      needs a base-sysroot fetch (clone `scripts/fetch-freebsd-base.sh`). BSD
      base is freely redistributable, like FreeBSD.

## Explicitly NOT in scope here

- **wasm (`wasm32-wasi`)** — a `ae build --target` concern, not a sysroot one.
  The C deps (openssl especially) don't build for wasm; Aether's `ci-wasm` uses a
  minimal runtime subset. No-external-dep wasm programs cross-compile with `-lm`
  alone and need nothing from this repo.
- **Anything that would require storing Apple SDK material** — see
  WHY-NOT-PUBLISHED.md. macOS system libs come only from bundled `zig cc`.

## Housekeeping / smaller items

- [ ] **nghttp2 for freebsd/windows**: confirm `--without-*` flags still suffice
      (no accidental libxml2/jansson/openssl pickup from the target sysroot).
- [ ] **Parallelism**: `provision.sh --all` builds targets serially; openssl
      dominates each. A `-jN`-across-targets mode could cut wall-clock on a big
      agent, but keep logs per-target legible.
- [ ] **A `verify.sh`**: after `provision.sh <triple>`, link a trivial
      Aether/C program that actually *uses* each lib (e.g. a pcre2 match, an
      openssl hash) against the sysroot and confirm it links `NOUNDEFS`. Closes
      the gap between "archive has the right arch" and "it actually links."
- [ ] **Run-on-hardware proof**: the one check no Linux agent can do — launch a
      linked mac-arm64 / windows binary on real hardware (or a `macos-14` /
      `windows` CI runner) and confirm it executes. Arch + symbol + libSystem
      evidence is conclusive that it's a valid image, but execution closes it.
