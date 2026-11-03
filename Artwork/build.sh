#!/bin/zsh
# Concatenates the generator parts, compiles them and paints every asset.
set -e
cd "$(dirname "$0")"
cat parts/*.swift > generate_assets.swift
swiftc -O -o /tmp/jj_gen generate_assets.swift
/tmp/jj_gen "${1:-../JewelJuggler/Assets.xcassets/Generated}" /tmp/jj_preview
