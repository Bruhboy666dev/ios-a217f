#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
out=${1:-"$here/out"}
bundle="$out/A135FMetalProbe.bundle"
mkdir -p "$bundle"
. "$HOME/ios-toolchain/env.sh"
: "${SDK:?iOS SDK missing}"
cc=${CC:-${IOS_CC:-clang -target arm64-apple-ios16.0 -fuse-ld=lld}}
# Intentional word splitting: this variable includes compiler target and linker flags.
# shellcheck disable=SC2086
$cc -isysroot "$SDK" -fobjc-runtime=ios-16.0 -fno-objc-arc -O2 -Wall -Wextra -Wno-builtin-requires-header \
    -bundle -Wl,-undefined,dynamic_lookup -framework Metal -framework Foundation \
    -o "$bundle/A135FMetalProbe" "$here/A135FMetalProbe.m"
if [ -x "$LDID" ]; then "$LDID" -S "$bundle/A135FMetalProbe"; fi
cat > "$bundle/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>A135FMetalProbe</string>
<key>CFBundleIdentifier</key><string>dev.a135f.metal-probe</string>
<key>CFBundleName</key><string>A135FMetalProbe</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>NSPrincipalClass</key><string>A135FMetalProbeDevice</string>
</dict></plist>
PLIST
echo "$bundle"
