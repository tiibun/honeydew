#!/bin/sh
# Update the bundled SQLite amalgamation to the latest version.
# Downloads only if the version has changed (or files are missing).
# Usage: sh scripts/update_sqlite.sh
set -e

DEST=honeydew/db/sqlite

# --- get latest version from the download page ---
PAGE=$(curl -s https://www.sqlite.org/download.html)
ZIP=$(echo "$PAGE" | grep -o 'sqlite-amalgamation-[0-9]*\.zip' | head -1)
PATH_IN_PAGE=$(echo "$PAGE" | grep -o '202[0-9]/'"$ZIP" | head -1)

if [ -z "$ZIP" ] || [ -z "$PATH_IN_PAGE" ]; then
  echo "Failed to find amalgamation URL on download page" >&2
  exit 1
fi

# ZIP filename encodes version as MAJOR*1000000 + MINOR*10000 + PATCH*100
# e.g. 3.51.3 -> 3510300
LATEST=$(echo "$ZIP" | grep -o '[0-9]*' | head -1)

# --- check current version using the same encoding ---
CURRENT=""
if [ -f "$DEST/sqlite3.h" ]; then
  VER=$(grep '#define SQLITE_VERSION ' "$DEST/sqlite3.h" | grep -o '"[0-9.]*"' | tr -d '"')
  MAJOR=$(echo "$VER" | cut -d. -f1)
  MINOR=$(echo "$VER" | cut -d. -f2)
  PATCH=$(echo "$VER" | cut -d. -f3)
  CURRENT=$(( MAJOR * 1000000 + MINOR * 10000 + PATCH * 100 ))
fi

if [ "$CURRENT" = "$LATEST" ]; then
  echo "Already up to date (SQLite $VER)"
  exit 0
fi

# --- download ---
URL="https://www.sqlite.org/${PATH_IN_PAGE}"
echo "Downloading $URL ..."
curl -L "$URL" -o /tmp/sqlite_update.zip

unzip -p /tmp/sqlite_update.zip "*/sqlite3.c" > "$DEST/sqlite3.c"
unzip -p /tmp/sqlite_update.zip "*/sqlite3.h" > "$DEST/sqlite3.h"
rm /tmp/sqlite_update.zip

NEW_VER=$(grep '#define SQLITE_VERSION ' "$DEST/sqlite3.h" | grep -o '"[0-9.]*"' | tr -d '"')
echo "Updated $DEST/sqlite3.{c,h}: ${VER:-none} -> $NEW_VER"
