# TODO

Extension work for aether-crossbuild. The script is structured so adding a
target is a few `case`-arms in `recipes/common.sh` (`map_zig_target`,
`map_autoconf_host`, `map_openssl_target`, `target_extra_cflags`) plus a `MATRIX`
entry — not a rewrite. Add **validated** targets only; a speculative row that
nobody has run rots into a broken row. Prove each new target builds at least one
lib before committing it to `MATRIX`.

## Direction decision (Nic) — is this whole matrix what we want?

Before more targets get added, **Nic needs to decide the direction**. The
current 8-target `MATRIX` was chosen by the person building this out, not ratified
— and only some of it maps to what Aether's CI already treats as "supported."
Three groups need an explicit yes/no, because they carry different maintenance
and provenance costs:

| Group | Targets | Status | Maps to Aether CI? | Decision needed |
|---|---|---|---|---|
| **Core** | linux-gnu ×2, macos ×2 | ✅ proven | Yes (ubuntu + macos are CI-gated) | Keep — uncontroversial |
| **musl** | `x86_64-linux-musl`, `aarch64-linux-musl` | ✅ proven | **No** — not in Aether CI | **Nic: do we want static-Linux builds?** |
| **FreeBSD** | `x86_64-freebsd`, `aarch64-freebsd` | ⚠️ base+zlib proven; autoconf libs blocked on Gap B (CRT link) | **No** — not in Aether CI | **Nic: do we support FreeBSD?** (Paul runs FreeBSD/GhostBSD infra; needs a stored base.txz per CPU) |
| **Windows** | `x86_64-windows`, `aarch64-windows` | ❌ not wired | **Yes** — heavily CI-gated (windows ~ as much as ubuntu) | **Nic: add? It's the one CI-parity gap** (details below) |

The tension to resolve: if the goal is **strict Aether-CI parity**, we'd *drop*
musl+FreeBSD and *add* Windows. But musl (static, distro-independent Linux
binaries) and FreeBSD (Paul's deploy infra) were added for real reasons beyond
CI parity. So the real question for Nic is **"is the goal CI parity, or broader
delivery coverage?"** — that answer decides which of the three groups stay.

Nothing below should be *built* until that direction is set. Each group's
technical notes are kept here so whichever way Nic goes, the work is scoped.

---

## Windows (x86_64 + aarch64) — the CI-parity gap

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

**Why it's the strongest case for adding:** Windows is the platform users least
want to build from source themselves, Aether already auto-fetches a MinGW
toolchain on Windows to spare them, and Aether CI gates on it as heavily as
Linux. If we're doing cross-compile delivery at all, "Windows .exe from a Linux
agent" is close to the point of the exercise.

## musl (x86_64 + aarch64) — static-Linux delivery [DECISION: Nic]

**Status: proven** (both build clean; verified distinct ELF x86-64 / aarch64).
Already in `MATRIX`. The open question is whether we *keep* it.

- **The pitch:** musl links a fully static, distro-independent Linux binary —
  "runs on any Linux, no glibc-version roulette." Great for containers, edge, and
  shipping a single binary to a machine you don't control.
- **Against:** not in Aether's CI matrix, so it's coverage *beyond* what the
  language formally supports. Two extra targets to maintain and CI-time to spend.
- **Nic decides:** keep musl ×2, or drop to glibc-only and treat static Linux as
  an on-demand extra? If kept, it's zero further work — it's done and validated.

## FreeBSD (x86_64 + aarch64) — BSD delivery [DECISION: Nic]

**Status (2026-07-21): base sysroot PROVEN, zlib cross-builds; the autoconf
recipes (pcre2/nghttp2/openssl) blocked on a LINK-side CRT gap.** The base path
is no longer untested — `fetch-freebsd-base.sh x86_64 15` extracts a usable
sysroot, `ae build --target=x86_64-freebsd` cross-links + runs REAL aeo on a
FreeBSD-15 box (jail/bhyve substrates detected). A `provision.sh x86_64-freebsd15`
run surfaced two recipe gaps (both twins of the tools/ae.c #1208 FreeBSD fixes —
the recipes were only exercised on Tier-A targets):

- [x] **Gap A (COMPILE) — FIXED:** `target_extra_cflags` emitted only
      `--sysroot`, so `#include <sys/types.h>` failed "file not found" (zlib died
      immediately). `--sysroot` ALONE doesn't add the base's include/lib for a
      FreeBSD target (unlike zig's bundled targets). Fixed to also emit
      `-I$B/usr/include -L$B/usr/lib -L$B/lib`. **zlib now builds + stages.**
- [ ] **Gap B (LINK) — OPEN:** pcre2's (and openssl's/nghttp2's) `./configure`
      link-probes a test executable, which on FreeBSD needs the CRT startup
      objects + real libc.so.7 (zig cc can't supply a FreeBSD libc):
      ```
      ld.lld: warning: cannot find entry symbol _start
      error: libc not available
      configure: error: C compiler cannot create executables
      ```
      There's a `target_extra_cflags` but no `target_extra_ldflags`. Fix mirrors
      ae.c's `fbsd_link`: add `target_extra_ldflags <triple>` emitting
      `-nostdlib $B/usr/lib/crt1.o $B/usr/lib/crti.o $B/lib/libc.so.7 $B/usr/lib/crtn.o`
      and thread it into each autoconf recipe's LDFLAGS + the run_configure env
      (zlib DIDN'T need it — hand-Makefile, `ar` only, no exe link; so this is
      specifically the autoconf/Configure recipes). NB zig exits nonzero with a
      cosmetic "libc not available" even when it links; configure has no
      output-exists escape hatch, so the CRT flags are mandatory here.
      AEO SCOPE: aeo needs only openssl+nghttp2+zlib (NOT pcre2 — no regex
      import), and zlib already builds; getting those three unblocks real-aeo's
      TLS half (secrets hmac + PVE https).

**Original decision framing below.** In `MATRIX`, base-sysroot path now proven
for the no-link-probe case (zlib), blocked on Gap B for the autoconf libs.

- **The pitch:** Paul runs FreeBSD / GhostBSD infrastructure; this is real deploy
  surface for him. BSD base is freely redistributable (no Apple-style restriction
  — the safe tier, licensing-wise).
- **The cost:** unlike the turnkey targets, FreeBSD needs a stored `base.txz`
  (~200 MB per CPU) fetched via `scripts/fetch-freebsd-base.sh`, because `zig cc`
  bundles no FreeBSD libc. So it's the one tier with a stored blob and an extra
  provisioning step.
- **Not in Aether CI** — coverage beyond formal support, justified by Paul's infra
  rather than parity.
- **Nic decides:** do we support FreeBSD as a target? If yes, the remaining work
  is:
  - [x] Run `scripts/fetch-freebsd-base.sh x86_64`... confirm the
        base extracts to a usable `--sysroot`.
  - [ ] Prove at least pcre2 + openssl cross-build against the FreeBSD sysroot
        (openssl uses `BSD-x86_64` / `BSD-aarch64` Configure targets — already
        wired in `map_openssl_target`).
  - [ ] Confirm `map_autoconf_host` FreeBSD hosts (`*-unknown-freebsd`) resolve.

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
