#!/usr/bin/env bash
# Compose reference, implementation, and blended screenshots at logical screen resolution.
set -euo pipefail
FIG=$1; IMPL=$2; OUT=$3; CT=${4:-}; CH=${5:-}
IW=$(magick identify -format %w "$IMPL"); IH=$(magick identify -format %h "$IMPL")
W=${CAMEO_W:-$(( IW / 3 ))}; H0=${CAMEO_H:-$(( IH / 3 ))}
TMP=$(mktemp -d)
if [ -n "$CT" ]; then magick "$FIG" -crop "${W}x${CH}+0+${CT}" +repage "$TMP/f.png"; else magick "$FIG" -resize "${W}x" "$TMP/f.png"; fi
H=$(magick identify -format %h "$TMP/f.png")
magick "$IMPL" -resize "${W}x${H0}!" -crop "${W}x${H}+0+0" +repage "$TMP/i.png"
magick "$TMP/f.png" "$TMP/i.png" -compose blend -define compose:args=50 -composite "$TMP/b.png"
magick "$TMP/f.png" "$TMP/i.png" "$TMP/b.png" -background white -splice 6x0 +append -chop 6x0 "$OUT"
rm -rf "$TMP"; echo "$OUT"
