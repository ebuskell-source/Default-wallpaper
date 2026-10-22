#!/bin/sh
# Builds tla-player (both kinds of Mac) from player.c: zig cc (pip install ziglang), then llvm-lipo.
set -e
cd "$(dirname "$0")"
for arch in aarch64 x86_64; do
  python3 -m ziglang cc -target $arch-macos.13.0 -O2 -Wall -Wextra -Wno-unused-parameter -o tla-player-$arch player.c
done
/usr/lib/llvm-18/bin/llvm-lipo -create tla-player-aarch64 tla-player-x86_64 -output tla-player
/usr/lib/llvm-18/bin/llvm-lipo -info tla-player
