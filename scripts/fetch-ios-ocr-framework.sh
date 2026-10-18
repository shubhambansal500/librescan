#!/usr/bin/env bash
# Downloads SwiftyTesseract's libtesseract.xcframework (~210MB, Apache-2.0)
# and places it where third_party/tesseract_ocr_patched/ios/libtesseract.podspec
# expects it. Required once before `pod install` / `flutter build ios` —
# see README.md "iOS OCR framework". Not committed to git: this script is
# the mechanism for getting it onto your machine instead.
set -euo pipefail

VERSION="0.2.0"
URL="https://github.com/SwiftyTesseract/libtesseract/releases/download/${VERSION}/libtesseract-${VERSION}.xcframework.zip"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$REPO_ROOT/third_party/tesseract_ocr_patched/ios"
TARGET="$DEST_DIR/libtesseract.xcframework"

if [ -d "$TARGET" ]; then
  echo "Already present: $TARGET"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading libtesseract $VERSION xcframework (~210MB)..."
curl -fSL --retry 3 -o "$TMP/libtesseract.xcframework.zip" "$URL"

echo "Extracting..."
unzip -q "$TMP/libtesseract.xcframework.zip" -d "$TMP/extracted"

FOUND="$(find "$TMP/extracted" -maxdepth 2 -iname '*.xcframework' -type d | head -1)"
if [ -z "$FOUND" ]; then
  echo "Could not find an .xcframework folder inside the downloaded zip." >&2
  echo "Check $URL is still the correct release asset." >&2
  exit 1
fi

mv "$FOUND" "$TARGET"
echo "Installed to $TARGET"
