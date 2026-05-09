#!/bin/bash
# Auto-updater for yandex-browser
set -euo pipefail

TEMPLATE="$(dirname "$0")/template"
CURRENT=$(grep '^version=' "${TEMPLATE}" | cut -d= -f2)

echo "Fetching latest Yandex Browser version from Yandex repo..."

PACKAGES=$(curl -fsSL \
    "https://repo.yandex.ru/yandex-browser/deb/dists/stable/main/binary-amd64/Packages.gz" \
    | gunzip -c)

LATEST=$(echo "${PACKAGES}" | grep '^Version:' | head -1 | grep -oP '[\d\.]+(?=-1)')
FILENAME=$(echo "${PACKAGES}" | grep '^Filename:' | head -1 | awk '{print $2}')

if [ -z "${LATEST}" ] || [ -z "${FILENAME}" ]; then
    echo "ERROR: Could not parse Packages.gz" >&2
    exit 1
fi

# Extract channel from actual filename: yandex-browser-corporate_... → corporate
CHANNEL=$(basename "${FILENAME}" | grep -oP 'yandex-browser-\K[^_]+(?=_)')

if [ -z "${CHANNEL}" ]; then
    echo "ERROR: Could not detect channel from filename: ${FILENAME}" >&2
    exit 1
fi

echo "Channel: ${CHANNEL}"

if [ "${CURRENT}" = "${LATEST}" ]; then
    echo "yandex-browser: ${CURRENT} — already up to date"
    exit 0
fi

echo "yandex-browser: ${CURRENT} → ${LATEST}"

DOWNLOAD_URL="https://repo.yandex.ru/yandex-browser/deb/${FILENAME}"
echo "URL: ${DOWNLOAD_URL}"
echo "Computing checksum..."
CHECKSUM=$(curl -fsSL "${DOWNLOAD_URL}" | sha256sum | cut -d' ' -f1)

sed -i "s/^version=.*/version=${LATEST}/" "${TEMPLATE}"
sed -i "s/^checksum=.*/checksum=${CHECKSUM}/" "${TEMPLATE}"
sed -i "s/^revision=.*/revision=1/" "${TEMPLATE}"
sed -i "s/^_channel=.*/_channel=${CHANNEL}/" "${TEMPLATE}"

echo "Done: ${LATEST} channel=${CHANNEL} (${CHECKSUM:0:16}...)"