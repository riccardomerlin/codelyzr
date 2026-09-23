#!/bin/bash
# Verifies countLinesOfCode wires .pathExclusions/.fileExclusions into cloc correctly.
# No test framework: extracts just the function (avoids sourcing code-analysis.sh's
# top-level `cd /data` / mkdir side effects) and stubs cloc to capture its args.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../code-analysis.sh"
failures=0

assert_contains() {
   local haystack="$1" needle="$2" label="$3"
   if [[ "$haystack" != *"$needle"* ]]; then
      echo "FAIL: $label - expected to find: $needle"
      echo "  actual args: $haystack"
      failures=$((failures + 1))
   fi
}

assert_not_contains() {
   local haystack="$1" needle="$2" label="$3"
   if [[ "$haystack" == *"$needle"* ]]; then
      echo "FAIL: $label - expected NOT to find: $needle"
      echo "  actual args: $haystack"
      failures=$((failures + 1))
   fi
}

run_case() {
   local caseName="$1"; shift
   local setupFn="${1:-}"; [ $# -gt 0 ] && shift

   local workDir; workDir=$(mktemp -d)
   local binDir="$workDir/bin"
   mkdir -p "$binDir"

   # fake cloc: records its args and writes a fake report (with a SUM line to strip)
   cat > "$binDir/cloc" <<'EOF'
#!/bin/bash
echo "$@" > "$CLOC_CAPTURE_FILE"
reportFile=""
for arg in "$@"; do
   case "$arg" in
      --report-file=*) reportFile="${arg#--report-file=}" ;;
   esac
done
printf "a.js,1,2,3\nSUM,1,2,3\n" > "$reportFile"
EOF
   chmod +x "$binDir/cloc"

   HOTSPOTS_FOLDER="$workDir/hotspots"
   ANALYSIS_FOLDER="$workDir/analysis"
   mkdir -p "$HOTSPOTS_FOLDER" "$ANALYSIS_FOLDER"
   export CLOC_CAPTURE_FILE="$workDir/cloc_args.txt"

   # pull just the countLinesOfCode function body out of the real script
   eval "$(sed -n '/^function countLinesOfCode/,/^}/p' "$TARGET_SCRIPT")"
   log() { :; }
   logDone() { :; }

   [ -n "$setupFn" ] && "$setupFn" # writes exclusion files before running, if given

   local savedPath="$PATH"
   PATH="$binDir:$PATH"
   countLinesOfCode
   PATH="$savedPath"

   clocArgsCaptured=$(cat "$CLOC_CAPTURE_FILE" 2>/dev/null || echo "<cloc not called>")
   echo "-- $caseName --"

   __LAST_WORKDIR="$workDir"
   __LAST_ARGS="$clocArgsCaptured"
   __LAST_REPORT="$ANALYSIS_FOLDER/lines_by_file.csv"
}

# Case 1: no exclusion files -> cloc called with no exclusion flags
run_case "no exclusions"
assert_not_contains "$__LAST_ARGS" "--exclude-list-file" "no exclusions: exclude-list-file absent"
assert_not_contains "$__LAST_ARGS" "--not-match-f" "no exclusions: not-match-f absent"
grep -q "^SUM" "$__LAST_REPORT" && { echo "FAIL: SUM line not stripped"; failures=$((failures + 1)); }

# Case 2: .pathExclusions -> exact-match exclude-list-file, literal content preserved
setup_path_exclusions() {
   printf "vendor/\ndocs/\n" > "$HOTSPOTS_FOLDER/.pathExclusions"
}
run_case ".pathExclusions" setup_path_exclusions
assert_contains "$__LAST_ARGS" "--exclude-list-file=" "pathExclusions: exclude-list-file present"
excludeListPath=$(echo "$__LAST_ARGS" | grep -o -- '--exclude-list-file=[^ ]*' | sed 's/--exclude-list-file=//')
if [ -f "$excludeListPath" ]; then
   content=$(cat "$excludeListPath")
   assert_contains "$content" "vendor/" "pathExclusions: content has vendor/"
   assert_contains "$content" "docs/" "pathExclusions: content has docs/"
else
   echo "FAIL: exclude-list-file path not found on disk: $excludeListPath"
   failures=$((failures + 1))
fi
assert_not_contains "$__LAST_ARGS" "--not-match-f" "pathExclusions only: not-match-f absent"

# Case 3: .fileExclusions -> regex-based --not-match-f, joined with |, matched full path
setup_file_exclusions() {
   printf '\\.spec\\.ts$\ngenerated_.*\n' > "$HOTSPOTS_FOLDER/.fileExclusions"
}
run_case ".fileExclusions" setup_file_exclusions
assert_contains "$__LAST_ARGS" "--fullpath" "fileExclusions: --fullpath present"
assert_contains "$__LAST_ARGS" '--not-match-f=\.spec\.ts$|generated_.*' "fileExclusions: regex joined with |"
assert_not_contains "$__LAST_ARGS" "--exclude-list-file" "fileExclusions only: exclude-list-file absent"

# Case 4: both files present -> both flags present together
setup_both() {
   setup_path_exclusions
   setup_file_exclusions
}
run_case "both exclusions" setup_both
assert_contains "$__LAST_ARGS" "--exclude-list-file=" "both: exclude-list-file present"
assert_contains "$__LAST_ARGS" "--not-match-f=" "both: not-match-f present"

if [ "$failures" -eq 0 ]; then
   echo "PASS: all countLinesOfCode assertions passed"
   exit 0
else
   echo "$failures assertion(s) failed"
   exit 1
fi
