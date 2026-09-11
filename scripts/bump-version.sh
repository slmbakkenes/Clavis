#!/bin/bash
# Bumps the patch version and the build number in Resources/Info.plist.
# Commits and tags are left to you.

set -euo pipefail

cd "$(dirname "$0")/.."

PLIST="Resources/Info.plist"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")

IFS=. read -r MAJOR MINOR PATCH <<<"$VERSION"
NEXT_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
NEXT_BUILD=$((BUILD + 1))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${NEXT_VERSION}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${NEXT_BUILD}" "$PLIST"

echo "Bumped to ${NEXT_VERSION} (build ${NEXT_BUILD}). Review with 'git diff', then commit when ready."
