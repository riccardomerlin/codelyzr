#!/usr/bin/env bats

SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../code-analysis.sh"

# Creates a throwaway git repo in a fresh temp dir and prints its path.
create_fixture_repo() {
   local repo_dir
   repo_dir=$(mktemp -d)
   git init --quiet "$repo_dir"
   git -C "$repo_dir" config user.email "fixture@example.com"
   git -C "$repo_dir" config user.name "Fixture"
   echo "$repo_dir"
}

# Commits a new file into the given repo, with author/committer date fixed
# so git log's --after filtering is deterministic regardless of when the
# test actually runs.
commit_file_at_date() {
   local repo_dir="$1" file_name="$2" commit_date="$3"
   echo "content" > "$repo_dir/$file_name"
   git -C "$repo_dir" add "$file_name"
   GIT_AUTHOR_DATE="$commit_date" GIT_COMMITTER_DATE="$commit_date" \
      git -C "$repo_dir" commit --quiet -m "add $file_name"
}

# Points the script under test at the given repo and sources it, so its
# functions and folder variables (e.g. $ANALYSIS_FOLDER) become available.
use_repo_as_data_folder() {
   local repo_dir="$1"
   export DATA_FOLDER="$repo_dir"
   source "$SCRIPT_UNDER_TEST"
}

@test "retrieveGitLogs includes only commits made after startDate" {
   local repo_dir
   repo_dir=$(create_fixture_repo)
   commit_file_at_date "$repo_dir" "before.txt" "2020-01-01T00:00:00"
   commit_file_at_date "$repo_dir" "after.txt" "2020-06-01T00:00:00"

   use_repo_as_data_folder "$repo_dir"
   startDate="2020-03-01"

   retrieveGitLogs

   run grep --fixed-strings "after.txt" "$ANALYSIS_FOLDER/git.log"
   [ "$status" -eq 0 ]

   run grep --fixed-strings "before.txt" "$ANALYSIS_FOLDER/git.log"
   [ "$status" -eq 1 ]
}

@test "retrieveGitLogs omits commits touching only a path listed in .pathExclusions" {
   local repo_dir
   repo_dir=$(create_fixture_repo)
   mkdir -p "$repo_dir/excluded-dir"
   commit_file_at_date "$repo_dir" "included.txt" "2020-06-01T00:00:00"
   commit_file_at_date "$repo_dir" "excluded-dir/excluded.txt" "2020-06-02T00:00:00"

   use_repo_as_data_folder "$repo_dir"
   startDate="2020-01-01"
   echo "excluded-dir/" > "$HOTSPOTS_FOLDER/.pathExclusions"

   retrieveGitLogs

   run grep --fixed-strings "included.txt" "$ANALYSIS_FOLDER/git.log"
   [ "$status" -eq 0 ]

   run grep --fixed-strings "excluded.txt" "$ANALYSIS_FOLDER/git.log"
   [ "$status" -eq 1 ]
}

@test "retrieveGitLogs leaves log unfiltered when no .pathExclusions file exists" {
   local repo_dir
   repo_dir=$(create_fixture_repo)
   mkdir -p "$repo_dir/some-dir"
   commit_file_at_date "$repo_dir" "some-dir/file.txt" "2020-06-01T00:00:00"

   use_repo_as_data_folder "$repo_dir"
   startDate="2020-01-01"

   retrieveGitLogs

   run grep --fixed-strings "file.txt" "$ANALYSIS_FOLDER/git.log"
   [ "$status" -eq 0 ]
}

@test "retrieveGitLogs writes each commit as a git2 header line followed by its numstat body" {
   local repo_dir
   repo_dir=$(create_fixture_repo)
   mkdir -p "$repo_dir/some-dir"
   commit_file_at_date "$repo_dir" "some-dir/file.txt" "2020-06-01T00:00:00"

   use_repo_as_data_folder "$repo_dir"
   startDate="2020-01-01"

   retrieveGitLogs

   run grep -E --after-context=1 '^--[0-9a-f]+--[0-9]{4}-[0-9]{2}-[0-9]{2}--.+$' "$ANALYSIS_FOLDER/git.log"
   [ "$status" -eq 0 ]
   [[ "${lines[0]}" =~ ^--[0-9a-f]+--[0-9]{4}-[0-9]{2}-[0-9]{2}--.+$ ]]
   [[ "${lines[1]}" =~ ^[0-9]+$'\t'[0-9]+$'\t'.*file\.txt$ ]]
}

@test "retrieveGitLogs excludes commits only reachable from a branch other than the current one" {
   local repo_dir
   repo_dir=$(create_fixture_repo)
   commit_file_at_date "$repo_dir" "main-only.txt" "2020-06-01T00:00:00"
   local original_branch
   original_branch=$(git -C "$repo_dir" symbolic-ref --short HEAD)
   git -C "$repo_dir" checkout --quiet -b other-branch
   commit_file_at_date "$repo_dir" "other-branch-only.txt" "2020-06-02T00:00:00"
   git -C "$repo_dir" checkout --quiet "$original_branch"

   use_repo_as_data_folder "$repo_dir"
   startDate="2020-01-01"

   retrieveGitLogs

   run grep --fixed-strings "other-branch-only.txt" "$ANALYSIS_FOLDER/git.log"
   [ "$status" -eq 1 ]
}
