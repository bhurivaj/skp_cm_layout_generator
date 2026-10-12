#!/bin/sh
# Build skp_cm_layout_generator_<VERSION>.rbz (loader + plugin folder only)
set -e
cd "$(dirname "$0")"
NAME=skp_cm_layout_generator
VERSION=$(sed -n "s/^ *VERSION = '\([0-9.]*\)'.*/\1/p" "$NAME.rb")
[ -n "$VERSION" ] || { echo "VERSION not found in $NAME.rb"; exit 1; }
[ -f "$NAME/templates/CIxCM.layout" ] || { echo "Missing $NAME/templates/CIxCM.layout"; exit 1; }
OUT="${NAME}_${VERSION}.rbz"
rm -f "$OUT"
zip -r "$OUT" "$NAME.rb" "$NAME" -x '*.DS_Store'
echo "Built $OUT"
