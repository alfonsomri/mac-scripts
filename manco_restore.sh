#!/usr/bin/env bash
set -euo pipefail

MDS="/Volumes/MDS"
WORKFLOW_ID="OS157OEM-72f0eef71512de99"

INSTALL_APP="$MDS/Deploy/macOS/Install macOS Sequoia 15.7_24G222.app"
SCRIPT_DIR="$MDS/Deploy/Workflows/$WORKFLOW_ID/WorkflowScripts"
# We will skip PreOS_PKG_DIR for speed
ADDITIONAL_PKG_DIR="$MDS/Deploy/Workflows/$WORKFLOW_ID/Packages"

TARGET_VOL="/Volumes/Macintosh HD"
ERASE=false
NEWVOL_NAME="Macintosh HD"

# Put temp/cache on internal disk (NOT Recovery RAM disk)
MDSTMP="$TARGET_VOL/Users/Shared/mds_tmp"
mkdir -p "$MDSTMP"
export TMPDIR="$MDSTMP"
export CACHEDIR="$MDSTMP"
export HOME="$MDSTMP"

# Checks
[ -d "$MDS" ] || { echo "ERROR: MDS not found at $MDS"; exit 1; }
[ -d "$INSTALL_APP" ] || { echo "ERROR: Installer not found at $INSTALL_APP"; exit 1; }
[ -d "$TARGET_VOL" ] || { echo "ERROR: Target volume not mounted: $TARGET_VOL"; exit 1; }

# Best-effort speed-ups on USB (ignore errors)
xattr -dr com.apple.quarantine "$MDS" 2>/dev/null || true
mdutil -i off "$MDS" 2>/dev/null || true

# Run any workflow scripts (portable loop; no process substitution)
if [ -d "$SCRIPT_DIR" ]; then
  echo "==> Running scripts in: $SCRIPT_DIR"
  export CURRENT_VOLUME_PATH="$MDS"
  find "$SCRIPT_DIR" -type f -name "*.sh" -print0 | \
  while IFS= read -r -d '' s; do
    echo "----> $s"
    chmod +x "$s" || true
    /bin/bash "$s"
  done
fi

STARTOSINSTALL="$INSTALL_APP/Contents/Resources/startosinstall"
[ -x "$STARTOSINSTALL" ] || { echo "ERROR: startosinstall missing"; exit 1; }

# Build args without arrays (works in Bash 3.2)
set -- "--agreetolicense" "--nointeraction"
if [ "$ERASE" = "true" ]; then
  set -- "$@" "--eraseinstall" "--newvolumename" "$NEWVOL_NAME"
else
  set -- "$@" "--volume" "$TARGET_VOL"
fi

# Inject packages
if [ -d "$ADDITIONAL_PKG_DIR" ]; then
  # shellcheck disable=SC2045
  for pkg in $(/bin/ls -1 "$ADDITIONAL_PKG_DIR" 2>/dev/null | awk '/\.pkg$/'); do
    set -- "$@" "--installpackage" "$ADDITIONAL_PKG_DIR/$pkg"
  done
fi

echo "==> Running:"
echo "     $STARTOSINSTALL $*"
exec "$STARTOSINSTALL" "$@"
