#!/bin/sh
# Builds tla-player and tla-signin (5.7.0) for both kinds of Mac, from player.c and tla-signin.c: zig cc
# (pip install ziglang), then llvm-lipo.
set -e
cd "$(dirname "$0")"
for prog in tla-player:player.c tla-signin:tla-signin.c; do
  name="${prog%%:*}"; src="${prog#*:}"
  for arch in aarch64 x86_64; do
    python3 -m ziglang cc -target $arch-macos.13.0 -O2 -Wall -Wextra -Wno-unused-parameter -o $name-$arch $src
  done
  /usr/lib/llvm-18/bin/llvm-lipo -create $name-aarch64 $name-x86_64 -output $name
  /usr/lib/llvm-18/bin/llvm-lipo -info $name
done
