#!/bin/bash
# Integration test: runs countLinesOfCode against a real git repo with real cloc
# (installed via npm as a devDependency, cross-OS since it just needs perl).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../code-analysis.sh"
source "$SCRIPT_DIR/test_helpers.sh"
failures=0

assert_has_file() {
   local csv="$1" filePath="$2" label="$3"
   if ! grep -q ",$filePath," "$csv" 2>/dev/null && ! grep -q ",$filePath$" "$csv" 2>/dev/null; then
      echo "FAIL: $label - expected $filePath present in $csv"
      cat "$csv" 2>/dev/null
      failures=$((failures + 1))
   fi
}

assert_missing_file() {
   local csv="$1" filePath="$2" label="$3"
   if grep -q "$filePath" "$csv" 2>/dev/null; then
      echo "FAIL: $label - expected $filePath absent from $csv"
      cat "$csv" 2>/dev/null
      failures=$((failures + 1))
   fi
}

command -v npx >/dev/null 2>&1 || { echo "SKIP: npx not found, cannot run integration test"; exit 0; }

workDir=$(new_case_dir "integration")
repoDir="$workDir/repo"
analysisDir="$workDir/analysis"
hotspotsDir="$workDir/hotspots"
mkdir -p "$repoDir/app" "$repoDir/vendor" "$repoDir/app/bin/obj" "$analysisDir" "$hotspotsDir"

git -C "$repoDir" init -q
git -C "$repoDir" config user.email "test@test.com"
git -C "$repoDir" config user.name "test"

printf 'function main() {\n  console.log("a");\n  console.log("b");\n  return 1;\n}\n' > "$repoDir/app/main.js"
printf 'describe("main", () => {\n  it("works", () => {\n    expect(1).toBe(1);\n  });\n});\n' > "$repoDir/app/main.spec.ts"
printf 'function lib() {\n  console.log("vendor");\n  return 2;\n}\n' > "$repoDir/vendor/lib.js"
printf 'class Generated {\n  void Run() {}\n}\n' > "$repoDir/app/bin/obj/generated.cs"

git -C "$repoDir" add -A
git -C "$repoDir" commit -q -m "fixture"

# real cloc on PATH, cross-OS via the npm devDependency
export PATH="$REPO_ROOT/node_modules/.bin:$PATH"
command -v cloc >/dev/null 2>&1 || { echo "SKIP: cloc not installed (run npm install)"; exit 0; }

run_in_repo() {
   ( cd "$repoDir" && HOTSPOTS_FOLDER="$hotspotsDir" ANALYSIS_FOLDER="$analysisDir" bash -c "
      $(sed -n '/^function countLinesOfCode/,/^}/p' "$TARGET_SCRIPT")
      log() { :; }; logDone() { :; }
      countLinesOfCode
   " )
}

# Case 1: no exclusions -> all three files counted
rm -f "$hotspotsDir/.pathExclusions" "$hotspotsDir/.fileExclusions"
run_in_repo
csv="$analysisDir/lines_by_file.csv"
echo "-- no exclusions --"
assert_has_file "$csv" "\./app/main.js" "no exclusions: main.js present"
assert_has_file "$csv" "\./app/main.spec.ts" "no exclusions: main.spec.ts present"
assert_has_file "$csv" "\./vendor/lib.js" "no exclusions: vendor/lib.js present"
assert_has_file "$csv" "\./app/bin/obj/generated.cs" "no exclusions: generated.cs present"

# Case 2: .pathExclusions uses glob patterns like the real repo (vendor/*, */obj/*),
# .fileExclusions excludes *.spec.ts
printf 'vendor/*\n*/obj/*\n' > "$hotspotsDir/.pathExclusions"
printf '\\.spec\\.ts$\n' > "$hotspotsDir/.fileExclusions"
run_in_repo
echo "-- with exclusions --"
assert_has_file "$csv" "\./app/main.js" "with exclusions: main.js still present"
assert_missing_file "$csv" "main.spec.ts" "with exclusions: main.spec.ts excluded"
assert_missing_file "$csv" "vendor/lib.js" "with exclusions: vendor/lib.js excluded (glob path)"
assert_missing_file "$csv" "generated.cs" "with exclusions: generated.cs excluded (nested glob path)"

if [ "$failures" -eq 0 ]; then
   echo "PASS: countLinesOfCode integration test passed"
   exit 0
else
   echo "$failures assertion(s) failed"
   exit 1
fi
