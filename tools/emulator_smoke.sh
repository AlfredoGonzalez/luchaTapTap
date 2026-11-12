#!/usr/bin/env bash
# Runs inside the Android emulator job: installs the release APK, starts the
# app, waits, then prints what the system logged about it (crashes, ANRs).
set -u
APK=build/app/outputs/flutter-apk/app-release.apk
PKG=com.example.lucha_tap_tap
adb install -r "$APK" || { echo "INSTALL FAILED"; exit 1; }
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity"
for t in 10 20 30 45 60; do
  sleep 10
  echo "--- t=${t}s: process alive?"; adb shell pidof "$PKG" || echo "NO PROCESS"
done
echo "=== logcat (app, errors, ANR) ==="
adb logcat -d -v time | grep -E "AndroidRuntime|FATAL|ANR|am_anr|ActivityManager.*(Displayed|crash|anr)|flutter|$PKG|Choreographer|Skipped|libc.*Fatal|DEBUG" | tail -150
echo "=== screenshot ==="
adb exec-out screencap -p > smoke.png && ls -la smoke.png
echo "=== main thread state ==="
adb shell dumpsys activity processes | grep -A6 "$PKG" | head -30
