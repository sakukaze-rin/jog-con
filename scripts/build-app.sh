#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
configuration=${1:-debug}
case "$configuration" in debug|release) ;; *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;; esac
mkdir -p .build/cache .build/config .build/security .build/clang
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/clang"
swift build -c "$configuration" --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security
bin=$(swift build -c "$configuration" --show-bin-path --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security)
app="build/Jog-con.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/JogCon" "$app/Contents/MacOS/JogCon"
cp packaging/Info.plist "$app/Contents/Info.plist"
cp packaging/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier dev.jog-con.app "$app"
printf 'Built %s/%s\n' "$PWD" "$app"
