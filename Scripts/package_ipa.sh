#!/usr/bin/env bash
set -euo pipefail

# SmolMax iOS — Package .app into unsigned .ipa for external signing
echo "=================================================="
echo " Packaging SmolMax-iOS.ipa                        "
echo "=================================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-${PROJECT_DIR}/build/Build/Products/Release-iphoneos/SmolMax-iOS.app}"
OUTPUT_IPA="${PROJECT_DIR}/SmolMax-iOS.ipa"
PAYLOAD_DIR="${PROJECT_DIR}/build/Payload"

if [ ! -d "${APP_PATH}" ]; then
    echo "Error: Application bundle not found at: ${APP_PATH}"
    echo "Usage: ./package_ipa.sh [path/to/SmolMax-iOS.app]"
    exit 1
fi

echo "Found application bundle: ${APP_PATH}"

# Prepare Payload folder
rm -rf "${PROJECT_DIR}/build/Payload"
mkdir -p "${PAYLOAD_DIR}"

echo "Copying app into Payload..."
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"

# Validate bundle structure
echo "Validating bundle structure..."
if [ ! -f "${PAYLOAD_DIR}/SmolMax-iOS.app/Info.plist" ]; then
    echo "Error: Missing Info.plist inside app bundle!"
    exit 1
fi

# Verify architecture
if command -v lipo &> /dev/null; then
    echo "Checking binary architecture..."
    lipo -info "${PAYLOAD_DIR}/SmolMax-iOS.app/SmolMax-iOS" || true
fi

# Create IPA zip archive
echo "Zipping into IPA..."
cd "${PROJECT_DIR}/build"
zip -qr "${OUTPUT_IPA}" Payload

echo "Verifying created IPA..."
if [ -f "${OUTPUT_IPA}" ]; then
    IPA_SIZE=$(du -h "${OUTPUT_IPA}" | cut -f1)
    echo "SUCCESS: IPA generated successfully!"
    echo "Output: ${OUTPUT_IPA} (${IPA_SIZE})"
    echo ""
    echo "This IPA is ready to be uploaded to your external signing service."
else
    echo "Error: Failed to create IPA file."
    exit 1
fi
