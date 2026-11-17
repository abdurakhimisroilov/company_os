#!/bin/bash
set -e

echo "=== Building Company OS Release APK ==="

echo "1. Cleaning previous build artifacts..."
flutter clean

echo "2. Fetching dependencies..."
flutter pub get

echo "3. Building obfuscated release APK..."
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

echo "=== Build Complete ==="
echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
