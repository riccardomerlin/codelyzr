#!/bin/bash
# Shared test setup: static, gitignored .tmp dir, wiped at the start of each
# test file's run (but left in place after), with a unique-dir helper so
# concurrent/sequential test cases never collide.
# Usage: source "$SCRIPT_DIR/test_helpers.sh" at the top of a test file,
# after SCRIPT_DIR is set.

: "${SCRIPT_DIR:?test_helpers.sh requires SCRIPT_DIR to be set before sourcing}"

WORK_BASE="$SCRIPT_DIR/.tmp"
mkdir -p "$WORK_BASE"
rm -rf "$WORK_BASE"/* 2>/dev/null

new_case_dir() {
   local name="$1"
   local dir="$WORK_BASE/${name// /_}-$$-$RANDOM-$(date +%s%N 2>/dev/null || date +%s)"
   mkdir -p "$dir"
   echo "$dir"
}
