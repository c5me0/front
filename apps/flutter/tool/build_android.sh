#!/usr/bin/env bash
# Build an installable APK. macOS builds use native temporary storage so external
# drive AppleDouble files cannot enter Gradle's resource directories.
set -euo pipefail
app_dir="$(cd "$(dirname "$0")/.." && pwd)"
mode="--debug"
if [ "${1:-}" = "--release" ] || [ "${1:-}" = "--profile" ]; then
  mode="$1"
  shift
fi

build_command=("./tool/flutter.sh" "build" "apk" "$mode")
for arg in "$@"; do
  case "$arg" in
    --dart-define-from-file=*)
      config_file="${arg#*=}"
      if [[ "$config_file" != /* ]]; then config_file="$app_dir/$config_file"; fi
      build_command+=("--dart-define-from-file=$config_file")
      ;;
    *) build_command+=("$arg") ;;
  esac
done

build_dir="$app_dir"
staging_dir=""
cleanup() {
  if [ -n "$staging_dir" ]; then rm -rf -- "$staging_dir"; fi
}
trap cleanup EXIT
if [[ "${OSTYPE:-}" == darwin* ]]; then
  staging_dir="$(mktemp -d /private/tmp/cameo-android.XXXXXX)"
  build_dir="$staging_dir/app"
  mkdir -p "$build_dir"
  rsync -a \
    --exclude='._*' --exclude='.DS_Store' --exclude='.git/' \
    --exclude='build/' --exclude='.dart_tool/' --exclude='.gradle/' \
    --exclude='.flutter-sdk' --exclude='.flutter-plugins*' \
    --exclude='ios/' --exclude='macos/' --exclude='windows/' --exclude='linux/' \
    --exclude='test/' --exclude='integration_test/' --exclude='test_driver/' \
    "$app_dir/" "$build_dir/"
  if [ -e "$app_dir/.flutter-sdk" ]; then
    ln -s "$(cd "$app_dir/.flutter-sdk" && pwd -P)" "$build_dir/.flutter-sdk"
  fi
  # package_config.json contains paths to the application and must be regenerated here.
  (cd "$build_dir" && ./tool/flutter.sh pub get)
fi

cd "$build_dir"
"${build_command[@]}"

if [ -n "$staging_dir" ]; then
  output_dir="$app_dir/build/app/outputs/flutter-apk"
  mkdir -p "$output_dir"
  for apk in "$build_dir"/build/app/outputs/flutter-apk/*.apk; do
    cp "$apk" "$output_dir/"
  done
  printf 'APK output: %s\n' "$output_dir"
fi
