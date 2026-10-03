#!/usr/bin/env bash
#
# Builds Analyzer.app.
#
# Deliberately a script rather than an Xcode project. A .pbxproj is a large
# generated file that is painful to review and merge, and everything needed here
# is three commands: build the core's static library, compile Swift against it,
# and lay out a bundle. It also means CI can build the app without Xcode project
# tooling.
#
# The core lives in core/, a submodule: C++ built with CMake into one static
# library, libanalyzer.a. Nothing in this repository is compiled by CMake; it is
# only asked to build that one target.
#
# Usage: ./build.sh [--release] [--run]

set -euo pipefail

cd "$(dirname "$0")"
# The Rust core is a submodule pinned to a known revision, so this repository
# builds against one specific core rather than whatever happens to be checked
# out beside it. `git clone --recursive`, or `git submodule update --init`.
ROOT="$(cd core && pwd)"

if [[ ! -f "$ROOT/CMakeLists.txt" ]]; then
    echo "error: core/ is empty - run: git submodule update --init" >&2
    exit 1
fi

# Plain strings rather than arrays: macOS still ships bash 3.2, where expanding
# an empty array under `set -u` is an error.
PROFILE="debug"
BUILD_TYPE="Debug"
SWIFT_FLAGS="-Onone -g"
RUN=0

for arg in "$@"; do
    case "$arg" in
        --release)
            PROFILE="release"
            BUILD_TYPE="Release"
            SWIFT_FLAGS="-O"
            ;;
        --run) RUN=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

if ! command -v cmake > /dev/null; then
    echo "error: cmake not found - install it with: brew install cmake" >&2
    exit 1
fi

APP="build/Analyzer.app"
CORE_BUILD="build/core/$PROFILE"
LIB="$CORE_BUILD/lib/libanalyzer.a"
HEADER_DIR="build/include"

echo "==> building the core ($BUILD_TYPE)"
# Built outside the submodule, so core/ stays exactly the pinned revision.
cmake -S "$ROOT" -B "$CORE_BUILD" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DANALYZER_BUILD_TESTS=OFF > /dev/null
cmake --build "$CORE_BUILD" --target analyzer_bundle --parallel

# The header is the core's, hand-maintained there as the ABI contract. The
# module map has to sit beside it, so both are copied into one place.
rm -rf "$HEADER_DIR"
mkdir -p "$HEADER_DIR"
cp "$ROOT/include/analyzer.h" include/module.modulemap "$HEADER_DIR/"

echo "==> compiling Swift"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# shellcheck disable=SC2086
swiftc $SWIFT_FLAGS \
    -parse-as-library \
    -target arm64-apple-macos14.0 \
    -I "$HEADER_DIR" \
    -Xcc -fmodule-map-file="$HEADER_DIR/module.modulemap" \
    -Xcc -std=c23 \
    -framework AppKit -framework SwiftUI -framework Metal -framework MetalKit \
    -framework CoreAudio -framework AudioToolbox -framework CoreFoundation \
    "$LIB" -lc++ \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/Analyzer"

cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> signing"
# Ad-hoc is enough to run locally. Distribution needs a Developer ID and
# notarisation, which is a separate concern with its own credentials.
codesign --force --sign - \
    --entitlements /dev/null \
    --identifier dev.rossbower.analyzer \
    "$APP" 2>/dev/null || codesign --force --sign - "$APP"

echo "==> built $APP"

if [[ "$RUN" == "1" ]]; then
    echo "==> launching"
    open "$APP"
fi
