#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage --reporter expanded
