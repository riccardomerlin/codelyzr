#!/bin/bash

cd /data
DATA_FOLDER="/data"
HOTSPOTS_FOLDER="$DATA_FOLDER/hotspots"
mkdir -p "$HOTSPOTS_FOLDER"
ANALYSIS_FOLDER_NAME=analysis-$(date +"%Y-%m-%dT%H-%M-%S")
ANALYSIS_FOLDER=$HOTSPOTS_FOLDER/$ANALYSIS_FOLDER_NAME
mkdir -p "$ANALYSIS_FOLDER"
COMPLEXITY_TRENDS_FOLDER="$ANALYSIS_FOLDER/complexity-trends"
mkdir -p "$COMPLEXITY_TRENDS_FOLDER"

function log {
   currentDateTime=$(date +"%Y-%m-%d %T")
   echo -n "[$currentDateTime] $@" 1>&2
}

function logDone {
   echo "[DONE]"
}

function retrieveGitLogs {
   cd "$DATA_FOLDER"
   exclusions="./"
   FILE="$HOTSPOTS_FOLDER/.pathExclusions"
   if [ -f "$FILE" ]; then
      exclusions=$(sed 's/^/"\:\(exclude\)/' $FILE | sed 's/$/" /' | tr -d "\r\n")
   fi

   log "Retrieving git logs since ${startDate}..."
   git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames --after=${startDate} -- . "$exclusions" > "$ANALYSIS_FOLDER/git.log"
   
   logDone
}

function countLinesOfCode {
   log "Counting lines of code per file..."

   cloc --vcs git --by-file --csv --quiet --unix --report-file="$ANALYSIS_FOLDER/lines_by_file.csv" --exclude-dir=coverage,3rdParty,SqlCompare,.vscode,packages,node_modules,bin,test-bin,_webtests,lib,services,web,obj,bower_components,WebTestSolution,dist
   # remove last line that contain the SUM
   head -n -1 "$ANALYSIS_FOLDER/lines_by_file.csv" > "$ANALYSIS_FOLDER/temp.txt" ; mv "$ANALYSIS_FOLDER/temp.txt" "$ANALYSIS_FOLDER/lines_by_file.csv"
   
   logDone
}

function calculateChangeFrequencies {
   log "Calculating change frequency per file..."

   # alternative way that requires formatting to have a csv than can be read by maat-scripts
   # cd /data
   # startDate=$1
   # if [ -z "$startDate" ]
   # then
   #    git log --format=format: --name-only | grep -vE '^$' | sort | uniq -c | sort -r > /data/hotspots/frequencies.csv
   # else
   #    git log --format=format: --name-only --after=${startDate} | grep -vE '^$' | sort | uniq -c | sort -r > /data/hotspots/frequencies.csv
   # fi

   cd /usr/src/code-analysys
   java -jar code-maat/app-standalone.jar -l "$ANALYSIS_FOLDER/git.log" -c git2 -a revisions > "$ANALYSIS_FOLDER/frequencies.csv"
   
   logDone
}

function normalizeData {
   FILE="$HOTSPOTS_FOLDER/.fileExclusions"
   if [ -f "$FILE" ]; then
      log "Data normalization..."
      regex=$(sed 's/^/|/' $FILE | tr -d "\r\n" | sed -r 's/^\|//')
      sed --in-place --regexp-extended "/$regex/D" "$ANALYSIS_FOLDER/lines_by_file.csv"
      sed --in-place --regexp-extended "/$regex/D" "$ANALYSIS_FOLDER/frequencies.csv"
      logDone
   fi
}

function calculateHotspots {
   log "Calculating hotspots..."
   python maat-scripts/merge/merge_comp_freqs.py "$ANALYSIS_FOLDER/frequencies.csv" "$ANALYSIS_FOLDER/lines_by_file.csv" > "$ANALYSIS_FOLDER/freq_complexity.csv"
   logDone
}

function enclosingDiagrams {
   log "Hotspots for enclosing diagrams..."
   python maat-scripts/transform/csv_as_enclosure_json.py --structure "$ANALYSIS_FOLDER/lines_by_file.csv" --weights "$ANALYSIS_FOLDER/frequencies.csv" > "$ANALYSIS_FOLDER/hotspots.json"
   logDone
}

function top10Hotspots {
   log "Extracting top 10 hotspots..."

   sed -r 's/,.+$//' "$ANALYSIS_FOLDER/freq_complexity.csv" > "$ANALYSIS_FOLDER/temp.txt"
   head -11 "$ANALYSIS_FOLDER/temp.txt" | tail -n +2 > "$ANALYSIS_FOLDER/top10hotspots.txt"
   rm "$ANALYSIS_FOLDER/temp.txt"

   logDone
}

function complexityTrends {
   log "Calculating complexity trend per file..."

   cd /data

   for line in {1..10}
   do
      filePath=$(head -n $line $ANALYSIS_FOLDER/top10hotspots.txt | tail -1)
      git-miner --tab $tabSize -- ${filePath} > "$COMPLEXITY_TRENDS_FOLDER/hotspot$line.csv"
   done

   logDone
}

function copyFiles {
   log "Copying files..."

   cp /usr/src/code-analysys/complexity-file-trend.html "$COMPLEXITY_TRENDS_FOLDER"
   cp /usr/src/code-analysys/hotspots.html "$ANALYSIS_FOLDER"
   cp /usr/src/code-analysys/server.js "$HOTSPOTS_FOLDER"

   logDone
}


startDate=$1
if [ -z "$startDate" ]
then
   log "ERROR: startDate parameter missing. Please, add the date you want the analysis to start from in the format yyyy-mm-dd."
   exit 1
fi

tabSize=$2
if [ -z "$tabSize" ]
then
   log "ERROR: tabSize parameter missing. Please, provide the tab size of your codebase."
   exit 1
fi

copyFiles
retrieveGitLogs $startDate
countLinesOfCode
calculateChangeFrequencies # $startDate
normalizeData
calculateHotspots
enclosingDiagrams
top10Hotspots
complexityTrends

log "The End."
echo

echo "Start the web server and go to http://localhost:9000/$ANALYSIS_FOLDER_NAME/hotspots.html or http://localhost:9000/$ANALYSIS_FOLDER_NAME/complexity-trends/complexity-file-trend.html?file=hotspot1"
