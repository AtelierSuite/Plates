#!/bin/sh
set -eu

file="$CI_PRIMARY_REPOSITORY_PATH/Apple/CulinaryIntelligence/Sources/CulinaryIntelligence/Cloud/PlatesCloudAddress.swift"

if [ -z "${PLATES_CLOUD_URL:-}" ]; then
    echo "warning: PLATES_CLOUD_URL is not set, so this build has no recipe writer."
    exit 0
fi

case "$PLATES_CLOUD_URL" in
    https://*) ;;
    *) echo "error: PLATES_CLOUD_URL must start with https://"; exit 1 ;;
esac

case "$PLATES_CLOUD_URL" in
    *\"* | *\\*) echo "error: PLATES_CLOUD_URL must not contain quotes or backslashes"; exit 1 ;;
esac

sed -i '' "s|static let url = \"\"|static let url = \"$PLATES_CLOUD_URL\"|" "$file"
grep -q "static let url = \"$PLATES_CLOUD_URL\"" "$file"
