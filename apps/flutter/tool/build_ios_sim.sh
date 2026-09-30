#!/usr/bin/env bash
# Build for iOS Simulator. Remove exFAT AppleDouble files before Flutter and after CocoaPods run.
#
set -euo pipefail
cd "$(dirname "$0")/.."
find . -name '._*' -not -path './.git/*' -delete 2>/dev/null || true
mode="--debug"
if [ "${1:-}" = "--release" ]; then
  mode="--release"
  shift
fi

shim_dir="$(mktemp -d)"
trap 'rm -rf "$shim_dir"' EXIT
if real_pod="$(command -v pod)"; then
  ios_dir="$PWD/ios"
  cat > "$shim_dir/pod" <<EOF
#!/usr/bin/env bash
"$real_pod" "\$@"
status=\$?
find "$ios_dir" -name '._*' -delete 2>/dev/null || true
exit \$status
EOF
  chmod +x "$shim_dir/pod"
  export PATH="$shim_dir:$PATH"
fi

./tool/flutter.sh build ios --simulator "$mode" "$@"
