#!/bin/bash
# Auto-updater for minecraft-launcher (extracts version from tarball)
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT_VERSION=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)
TAR_URL="https://launcher.mojang.com/download/Minecraft.tar.gz"

echo "Checking for a new Minecraft Launcher version..."

TMP_TAR=$(mktemp)
trap 'rm -f "$TMP_TAR"' EXIT
curl -fsSL --output "$TMP_TAR" "$TAR_URL" || {
    echo "ERROR: Failed to download Minecraft.tar.gz" >&2
    exit 1
}

NEW_CHECKSUM=$(sha256sum "$TMP_TAR" | cut -d' ' -f1)

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_TAR" "$TMP_DIR"' EXIT
tar -xf "$TMP_TAR" -C "$TMP_DIR" --strip-components=1 || {
    echo "ERROR: Failed to extract tarball" >&2
    exit 1
}

LATEST_VERSION=""
if [ -f "${TMP_DIR}/version" ]; then
    LATEST_VERSION=$(cat "${TMP_DIR}/version" | tr -d '[:space:]')
elif [ -f "${TMP_DIR}/minecraft-launcher/version" ]; then
    LATEST_VERSION=$(cat "${TMP_DIR}/minecraft-launcher/version" | tr -d '[:space:]')
else
    FOUND_VERSION=$(find "${TMP_DIR}" -name "version" -type f | head -1)
    if [ -n "$FOUND_VERSION" ]; then
        LATEST_VERSION=$(cat "$FOUND_VERSION" | tr -d '[:space:]')
    fi
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Could not determine launcher version from tarball" >&2
    exit 1
fi

echo "Current version: ${CURRENT_VERSION}"
echo "Latest version:  ${LATEST_VERSION}"
echo "New checksum:    ${NEW_CHECKSUM:0:16}..."

if [ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ]; then
    CURRENT_CHECKSUM=$(grep '^checksum=' "${TEMPLATE}" | cut -d= -f2)
    if [ "${CURRENT_CHECKSUM}" = "${NEW_CHECKSUM}" ]; then
        echo "minecraft-launcher: up to date"
        exit 0
    else
        echo "Version unchanged but archive checksum differs. Updating checksum..."
        sed -i "s/^checksum=.*/checksum=${NEW_CHECKSUM}/" "${TEMPLATE}"
        echo "Checksum updated."
        exit 0
    fi
fi

sed -i "s/^version=.*/version=${LATEST_VERSION}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${NEW_CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"

echo "Done: updated to ${LATEST_VERSION} (${NEW_CHECKSUM:0:16}...)"
echo "WARNING: If the internal file structure of the launcher changes, this script may break."