#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
DRILL_ROOT=${GLEAMCMS_RESTORE_DRILL_DIR:-"$ROOT_DIR/.smoke/restore-drill-$$"}
DATA_DIR="$DRILL_ROOT/data"
RESTORED_DIR="$DRILL_ROOT/restored-data"
OUTPUT_DIR="$DRILL_ROOT/output"
ARCHIVE="$DRILL_ROOT/gleamcms-data.tar.gz"
mkdir -p "$DATA_DIR" "$OUTPUT_DIR"

printf '%s\n' "Creating isolated persistence fixture at $DATA_DIR"
(
  cd "$ROOT_DIR"
  GLEAMCMS_SECRET=restore-drill-secret \
  GLEAMCMS_ADMIN_TOKEN=restore-drill-token \
  GLEAMCMS_DATA_DIR="$DATA_DIR" \
  GLEAMCMS_OUTPUT_DIR="$OUTPUT_DIR" \
  GLEAMCMS_PORT=4380 \
  GLEAMCMS_IMPORT_LEGACY=false \
  gleam run >"$DRILL_ROOT/fixture.log" 2>&1 &
  pid=$!
  sleep 3
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
)

tar -czf "$ARCHIVE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
mkdir -p "$RESTORED_DIR"
tar -xzf "$ARCHIVE" -C "$RESTORED_DIR"

[ -f "$RESTORED_DIR/$(basename "$DATA_DIR")/datoms.DCD" ]
[ -f "$RESTORED_DIR/$(basename "$DATA_DIR")/schema.DAT" ]
[ -f "$RESTORED_DIR/$(basename "$DATA_DIR")/LATEST.LOG" ]

checksum=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
printf '%s\n' "RESTORE DRILL PASSED"
printf '%s\n' "archive=$ARCHIVE"
printf '%s\n' "sha256=$checksum"
printf '%s\n' "rpo=fixture-start timestamp recorded in $DRILL_ROOT/fixture.log"
printf '%s\n' "rto=archive extraction and file verification completed in this run"
