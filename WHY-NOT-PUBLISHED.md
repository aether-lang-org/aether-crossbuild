# Why the built sysroots are not published

**Read this before adding a GitHub Release, a release archive, or otherwise
uploading the contents of `sysroots/` anywhere public.** The short answer: don't.
This repo ships *recipes*, never *artifacts*. Here is the reasoning, tier by
tier, so a well-meaning contributor doesn't "helpfully" attach a kitchen-sink zip
of every sysroot and create a licensing liability.

This is engineering guidance written by the maintainers, **not legal advice**.
When in doubt, ask a lawyer — but the design below is structured specifically so
that most of the doubt never arises.

## The three tiers of what a cross-link consumes

### 1. Apple system libraries — NEVER in our possession

macOS binaries link against `libSystem`, `dyld`, CoreFoundation, and friends.
Their SDK stubs (`.tbd` files, framework headers) are governed by the Apple SDK
license, which restricts redistribution and (notably) ties SDK *use* to
Apple-branded hardware.

**We never touch, copy, or store any of it.** These come from `zig cc`, which
ships its own clean-room macOS libc / system-stub set. That is why the cross-link
works on a Linux box with no Apple SDK present. The provenance question for those
stubs is the Zig project's, not ours — and it stays that way as long as:

- `--target` sources macOS system libraries **only** from the bundled `zig cc`, and
- we **never** point `--sysroot` at a real Apple SDK copied off a Mac, and
- nothing under `bases/` or `sysroots/` ever contains an Apple `.tbd`, framework,
  or SDK header.

The one place this nearly leaked: **openssl's macOS build wants
`<CommonCrypto/CommonCryptoError.h>`**, an Apple-framework header. Rather than
supply it (which would drag Apple SDK material into the build), we compile
openssl with `-DOPENSSL_NO_APPLE_CRYPTO_RANDOM`, so it uses `getentropy` /
`arc4random` from libSystem instead. Apple framework surface: zero. This is
enforced in `recipes/openssl.sh`; do not remove that flag to "get native RNG."

### 2. Third-party libraries (openssl, zlib, nghttp2, pcre2) — permissive, built from source

These are Apache-2.0 / OpenSSL-license / zlib / BSD-ish. Their compiled binaries
*are* redistributable, with attribution. But we still **don't publish** them,
for two reasons:

- **Build-from-source is provenance-clean.** We `curl` the pinned upstream source
  (sha256-checked in `deps.lock`) and compile it ourselves. No scraping of
  Homebrew bottles / distro packages / vcpkg caches of unknown origin and ABI.
- **Publishing built binaries adds an attribution + NOTICE-shipping obligation
  at rest** for little benefit — anyone who wants the sysroot runs
  `./provision.sh` and gets a reproducible one from the same lock. We copy each
  upstream `LICENSE`/`NOTICE` into `sysroots/<triple>/licenses/` so the
  obligation is satisfied *for the person who builds and ships an Aether binary*,
  which is where it actually belongs.

So these *could* be published, but there's no reason to, and not publishing keeps
the repo a pure recipe with no artifacts to license-audit.

### 3. FreeBSD base sysroot — freely redistributable, but still kept local

Cross-building for FreeBSD needs its base system (headers + libc), which `zig cc`
does not bundle. We extract it from FreeBSD's published `base.txz`. FreeBSD's base
is BSD-licensed and **explicitly redistributable** — this is the one tier with no
Apple-style restriction. We still keep it under `bases/` (git-ignored) rather
than committing it, purely to keep the repo small and recipe-only; it is not a
licensing constraint, just hygiene.

## The rule, in one line

> **`--target` gets Apple/system libs from the bundled `zig cc`. `--sysroot` is
> for permissive third-party deps built from source (and the freely-licensed
> FreeBSD base) — never for anything copied out of an Apple SDK.**

## Enforcement

- `.gitignore` excludes `sysroots/`, `bases/`, `toolchain/`, and all build
  scratch, so artifacts cannot be committed by accident.
- `recipes/openssl.sh` pins `-DOPENSSL_NO_APPLE_CRYPTO_RANDOM` so no Apple
  framework header is ever needed.
- There is intentionally **no release workflow** in this repo. If you add one,
  you are changing the licensing posture — re-read this file and get sign-off
  first.
