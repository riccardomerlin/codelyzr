#!/bin/bash
function log {
   currentDateTime=$(date +"%Y-%m-%d %T")
   echo -n "[$currentDateTime] $@" 1>&2
}

function logDone {
   echo "[DONE]"
}

function retrieveGitLogs {
   exclusions="./"
   FILE="/data/hotspots/.pathExclusions"
   if [ -f "$FILE" ]; then
      exclusions=$(sed 's/^/"\:\(exclude\)/' $FILE | sed 's/$/" /' | tr -d "\r\n")
   fi

   startDate=$1
   if [ -z "$startDate" ]
   then
      log "Retrieving git logs since the beginning..."
      git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames -- . "$exclusions" > /data/hotspots/git.log
   else
      log "Retrieving git logs since ${startDate}..."
      git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames --after=${startDate} -- . "$exclusions" > /data/hotspots/git.log
   fi
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
   java -jar code-maat/app-standalone.jar -l /data/hotspots/git.log -c git2 -a revisions > /data/hotspots/frequencies.csv
   
   logDone
}

function normalizeData {
   FILE="/data/hotspots/.fileExclusions"
   if [ -f "$FILE" ]; then
      log "Data normalization..."
      regex=$(sed 's/^/|/' $FILE | tr -d "\r\n" | sed -r 's/^\|//')
      sed --in-place --regexp-extended "/$regex/d" /data/hotspots/lines_by_file.csv
      sed --in-place --regexp-extended "/$regex/d" /data/hotspots/frequencies.csv
      logDone
   fi
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

   sed -r 's/,.+$//' /data/hotspots/freq_complexity.csv > /data/hotspots/temp.txt
   head -11 /data/hotspots/temp.txt | tail -n +2 > /data/hotspots/top10hotspots.txt
   rm /data/hotspots/temp.txt

   logDone
}

function complexityTrends {
   log "Calculating complexity trend per file..."

   cd /data

   for line in {1..10}
   do
      filePath=$(head -n $line /data/hotspots/top10hotspots.txt | tail -1)
      # filename=$(basename $filePath)
      git-miner -- ${filePath} > "/data/hotspots/complexity-trends/hotspot$line.csv"
   done

   logDone
}

function copyFiles {
   log "Copying files..."

   cp /usr/src/code-analysys/complexity-file-trend.html /data/hotspots/complexity-trends
   cp /usr/src/code-analysys/hotspots.html /data/hotspots/
   cp /usr/src/code-analysys/server.js /data/hotspots/

   logDone
}

cd /data
mkdir -p hotspots
mkdir -p hotspots/complexity-trends

startDate=$1
retrieveGitLogs $startDate
countLinesOfCode
calculateChangeFrequencies # $startDate
normalizeData
calculateHotspots
enclosingDiagrams
top10Hotspots
complexityTrends
copyFiles

log "The End."
echo
