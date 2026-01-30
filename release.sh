#!/bin/bash
set -e

# Configuration
APP_NAME="forks"
INPUT_PATH="$1"

if [ -z "$INPUT_PATH" ]; then
    echo "Usage: ./release.sh <path_to_exported_folder>"
    exit 1
fi

# Ensure tools exist
if [ ! -d "tools/sparkle/bin" ]; then
    echo "Error: Sparkle tools not found in tools/sparkle/bin"
    echo "Please download Sparkle 2.x and extract it there."
    exit 1
fi

# Handle common path issues (remove trailing slash)
INPUT_PATH=${INPUT_PATH%/}

# If user passed the .app directly, verify it and use its parent dir
if [[ "$INPUT_PATH" == *".app" ]]; then
    APP_PATH="$INPUT_PATH"
    WORK_DIR="$(dirname "$APP_PATH")"
else
    WORK_DIR="$INPUT_PATH"
    # Find the app in the folder
    APP_PATH=$(find "$WORK_DIR" -maxdepth 1 -name "*.app" | head -n 1)
fi

if [ -z "$APP_PATH" ]; then
    echo "Error: No .app found in $WORK_DIR"
    exit 1
fi

echo "📂 Working directory: $WORK_DIR"
echo "📱 Found App: $APP_PATH"

# Zip the app if a zip doesn't already exist
ZIP_NAME="$(basename "$APP_PATH" .app).zip"
ZIP_PATH="$WORK_DIR/$ZIP_NAME"

if [ ! -f "$ZIP_PATH" ]; then
    echo "📦 Zipping $APP_PATH..."
    # Zip strictly the .app, not the full path structure
    # -j truncates paths? No, we want to cd into dir and zip.
    
    APP_BASENAME="$(basename "$APP_PATH")"
    pushd "$WORK_DIR" > /dev/null
    zip -r -y "$ZIP_NAME" "$APP_BASENAME"
    popd > /dev/null
    
    echo "✅ Created $ZIP_PATH"
else
    echo "ℹ️  Zip already exists: $ZIP_PATH"
fi

echo "🚀 Generating Appcast..."

# Generate the appcast on the WORK_DIR
./tools/sparkle/bin/generate_appcast "$WORK_DIR"

echo "✅ Appcast generated at $WORK_DIR/appcast.xml"
echo ""
echo "Next Steps:"
echo "1. Upload '$ZIP_PATH' to GitHub Releases."
echo "2. Copy '$WORK_DIR/appcast.xml' to your repo root."
echo "3. Commit and push appcast.xml."
