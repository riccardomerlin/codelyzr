#!/bin/bash
function log {
   currentDateTime=$(date +"%Y-%m-%d %T")
   echo -n "[$currentDateTime] $@" 1>&2
}

function logDone {
   echo "[DONE]"
}

function retrieveGitLogs {
   log "Retrieving git logs..."
   git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames --after=2020-04-07 -- . ":(exclude)packges/*" ":(exclude)node_modules/*" ":(exclude)*/bower_components/*" ":(exclude)*/3rdParty/*" ":(exclude)*/bin/*" ":(exclude)*/test-bin/*" ":(exclude)*/obj/*" ":(exclude)dist/*" ":(exclude)_webtests/*" ":(exclude)WebTestSolution/*" > /data/hotspots/git.log
   logDone
}

function countLinesOfCode {
   log "Counting lines of code per file..."

   cloc --vcs git --by-file --csv --quiet --unix --report-file=/data/hotspots/lines_by_file.csv --exclude-dir=coverage,3rdParty,SqlCompare,.vscode,packages,node_modules,bin,test-bin,_webtests,lib,services,web,obj,bower_components,WebTestSolution,dist
   # remove last line that contain the SUM
   head -n -1 /data/hotspots/lines_by_file.csv > /data/hotspots/temp.txt ; mv /data/hotspots/temp.txt /data/hotspots/lines_by_file.csv
   
   logDone
}

function calculateChangeFrequencies {
   log "Calculating change frequency per file..."

   cd /usr/src/code-analysys
   java -jar code-maat/app-standalone.jar -l /data/hotspots/git.log -c git2 -a revisions > /data/hotspots/frequencies.csv
   
   logDone
}

function normalizeData {
   log "Data normalization..."
   sed --in-place --regexp-extended '/.*csproj.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*package(-lock)?\.json.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*yarn\.lock.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*(app|Web|packages|Local)\.Config.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*\.sln.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*ChangeSchema.sql.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*CHANGELOG.md.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*MigrationsList.cs.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*\.yml.*/d' /data/hotspots/lines_by_file.csv
   sed --in-place --regexp-extended '/.*\.yaml.*/d' /data/hotspots/lines_by_file.csv

   sed --in-place --regexp-extended '/.*csproj.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*package(-lock)?\.json.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*yarn\.lock.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*(app|Web|packages|Local)\.Config.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*\.sln.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*ChangeSchema.sql.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*CHANGELOG.md.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*MigrationsList.cs.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*\.yml.*/d' /data/hotspots/frequencies.csv
   sed --in-place --regexp-extended '/.*\.yaml.*/d' /data/hotspots/frequencies.csv

   logDone
}

function calculateHotspots {
   log "Calculating hotspots..."
   python maat-scripts/merge/merge_comp_freqs.py /data/hotspots/frequencies.csv /data/hotspots/lines_by_file.csv > /data/hotspots/freq_complexity.csv
   logDone
}

function enclosingDiagrams {
   log "Hotspots for enclosing diagrams..."
   python maat-scripts/transform/csv_as_enclosure_json.py --structure /data/hotspots/lines_by_file.csv --weights /data/hotspots/frequencies.csv > /data/hotspots/hotspots.json
   logDone
}

function top10Hotspots {
   log "Extracting top 10 hotspots..."

   cd /data
   sed -r 's/,.+$//' /data/hotspots/freq_complexity.csv > /data/hotspots/temp.txt
   head -11 /data/hotspots/temp.txt | tail -n +2 > /data/hotspots/top10hotspots.txt
   rm /data/hotspots/temp.txt

   logDone
}

function complexityTrends {
   log "Calculating complexity trend per file..."

   mkdir /data/hotspots/complexity-trends

   for line in {1..10}
   do
      filename=$(head -n $line /data/hotspots/top10hotspots.txt | tail -1)
      filename=$(basename $filename)
      git-miner -- ${filename} > "/data/hotspots/complexity-trends/hotspot$line-$filename.csv"
   done

   logDone
}

function copyHtmlPages {
   log "Copying html pages..."

   cp /usr/src/code-analysys/complexity-file-trend.html /data/hotspots/complexity-trends
   cp /usr/src/code-analysys/hotspots.html /data/hotspots/

   logDone
}

cd /data
mkdir -p hotspots

retrieveGitLogs
countLinesOfCode
calculateChangeFrequencies
normalizeData
calculateHotspots
enclosingDiagrams
top10Hotspots
complexityTrends
copyHtmlPages

echo "The End."
