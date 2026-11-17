@echo off
echo === Building Company OS Release APK ===

echo 1. Cleaning previous build artifacts...
call flutter clean

echo 2. Fetching dependencies...
call flutter pub get

echo 3. Building obfuscated release APK...
call flutter build apk --release --obfuscate --split-debug-info=build/debug-info

echo === Build Complete ===
echo APK location: build\app\outputs\flutter-apk\app-release.apk
pause
