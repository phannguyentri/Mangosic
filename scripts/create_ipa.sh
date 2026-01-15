#!/bin/bash

# Script to convert .xcarchive to .ipa for AltStore/Sideloading
# Usage: ./create_ipa.sh /path/to/YourApp.xcarchive

# 1. Validate Input
if [ -z "$1" ]; then
    echo "❌ Error: Please provide the path to the .xcarchive file"
    echo "Usage: $0 /path/to/YourApp.xcarchive"
    exit 1
fi

ARCHIVE_PATH="${1%/}" # Remove trailing slash

if [ ! -d "$ARCHIVE_PATH" ] || [[ "$ARCHIVE_PATH" != *".xcarchive" ]]; then
    echo "❌ Error: Invalid directory or not an .xcarchive: $ARCHIVE_PATH"
    exit 1
fi

# 2. Setup Variables
APP_NAME=$(basename "$ARCHIVE_PATH" .xcarchive)
OUTPUT_DIR=$(dirname "$ARCHIVE_PATH")
IPA_NAME="${APP_NAME}.ipa"
IPA_PATH="$OUTPUT_DIR/$IPA_NAME"

echo "📦 Processing: $APP_NAME"
echo "📂 Archive: $ARCHIVE_PATH"

# 3. Find .app bundle inside archive
APP_BUNDLE=$(find "$ARCHIVE_PATH/Products/Applications" -name "*.app" -maxdepth 1 | head -n 1)

if [ -z "$APP_BUNDLE" ]; then
    echo "❌ Error: Could not find .app bundle inside the archive."
    exit 1
fi

echo "🔎 Found App: $APP_BUNDLE"

# 4. Create Temporary Payload Structure
echo "⚙️  Packaging..."
TEMP_DIR=$(mktemp -d)
PAYLOAD_DIR="$TEMP_DIR/Payload"
mkdir -p "$PAYLOAD_DIR"

# Copy .app to Payload
cp -R "$APP_BUNDLE" "$PAYLOAD_DIR/"

# 5. Zip and Rename to .ipa
CURRENT_DIR=$(pwd)
cd "$TEMP_DIR" || exit
zip -qr "Mangosic.ipa" "Payload"

# Move correctly to output
mv "Mangosic.ipa" "$IPA_PATH"

# 6. Cleanup
cd "$CURRENT_DIR" || exit
rm -rf "$TEMP_DIR"

echo "✅ Success! IPA created at:"
echo "👉 $IPA_PATH"
open -R "$IPA_PATH"
