#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build_macos.sh [--clean] [--hwcodec] [--screencapturekit] [--skip-cargo]

Environment overrides:
  RUSTDESK_FLUTTER_ROOT       Flutter SDK root. Default: first flutter in PATH
  RUSTDESK_MACOS_CODEC_ROOT   Native dependency prefix. Optional
  PUB_CACHE                   Dart package cache. Default: $HOME/.pub-cache-rustdesk-macos
  CARGO_TARGET_DIR            Cargo output dir. Default: ../rustdesk-target-macos
USAGE
}

clean=0
hwcodec=0
screencapturekit=0
skip_cargo=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean) clean=1 ;;
    --hwcodec) hwcodec=1 ;;
    --screencapturekit) screencapturekit=1 ;;
    --skip-cargo) skip_cargo=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_dir="$repo_root/flutter"
default_codec_root="$repo_root/.local/macos-codecs"

if [[ -n "${RUSTDESK_FLUTTER_ROOT:-}" ]]; then
  export PATH="$RUSTDESK_FLUTTER_ROOT/bin:$PATH"
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found. Set RUSTDESK_FLUTTER_ROOT or put flutter in PATH." >&2
  exit 1
fi

export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache-rustdesk-macos}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$(cd "$repo_root/.." && pwd)/rustdesk-target-macos}"

if [[ -z "${RUSTDESK_MACOS_CODEC_ROOT:-}" ]]; then
  if [[ -d "$default_codec_root" ]]; then
    export RUSTDESK_MACOS_CODEC_ROOT="$default_codec_root"
  elif [[ -n "${CMAKE_PREFIX_PATH:-}" ]]; then
    export RUSTDESK_MACOS_CODEC_ROOT="${CMAKE_PREFIX_PATH%%:*}"
  fi
fi

if [[ -n "${RUSTDESK_MACOS_CODEC_ROOT:-}" ]]; then
  echo "Using macOS codec root: $RUSTDESK_MACOS_CODEC_ROOT"
  export CMAKE_PREFIX_PATH="$RUSTDESK_MACOS_CODEC_ROOT:${CMAKE_PREFIX_PATH:-}"
  export PKG_CONFIG_PATH="$RUSTDESK_MACOS_CODEC_ROOT/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
fi

mkdir -p "$PUB_CACHE" "$CARGO_TARGET_DIR"

package_config="$flutter_dir/.dart_tool/package_config.json"
if [[ "$clean" -eq 1 ]] ||
   [[ ! -f "$package_config" ]] ||
   grep -Eq 'file:///mnt/|file:///home/|flutter-win|\\' "$package_config" 2>/dev/null; then
  echo "Refreshing macOS Flutter metadata..."
  rm -rf "$flutter_dir/.dart_tool" "$flutter_dir/.flutter-plugins-dependencies" "$flutter_dir/build/macos"
fi

(cd "$flutter_dir" && flutter pub get)

features="flutter"
if [[ "$hwcodec" -eq 1 ]]; then
  features="$features hwcodec"
fi
if [[ "$screencapturekit" -eq 1 ]]; then
  features="$features screencapturekit"
fi

if [[ "$skip_cargo" -eq 0 ]]; then
  (cd "$repo_root" && MACOSX_DEPLOYMENT_TARGET=10.15 cargo build --features "$features" --lib --release)
fi

host_arch="$(uname -m)"
if [[ "$host_arch" == "arm64" || "$host_arch" == "x86_64" ]]; then
  (
    cd "$flutter_dir"
    flutter build macos --release --config-only
    xcodebuild -workspace macos/Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -derivedDataPath build/macos \
      -destination "platform=macOS,arch=$host_arch" \
      build
  )
else
  (cd "$flutter_dir" && flutter build macos --release)
fi

if [[ -f "$repo_root/target/release/service" ]]; then
  cp -f "$repo_root/target/release/service" \
    "$flutter_dir/build/macos/Build/Products/Release/RustDesk.app/Contents/MacOS/"
fi

echo "macOS bundle:"
echo "$flutter_dir/build/macos/Build/Products/Release"
