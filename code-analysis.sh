#!/bin/bash

cd /data
mkdir -p hotspots

# get git log
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames --after=2020-04-07 -- . ":(exclude)packges/*" ":(exclude)node_modules/*" ":(exclude)*/bower_components/*" ":(exclude)*/3rdParty/*" ":(exclude)*/bin/*" ":(exclude)*/test-bin/*" ":(exclude)*/obj/*" ":(exclude)dist/*" ":(exclude)_webtests/*" ":(exclude)WebTestSolution/*" > /data/hotspots/git.log

# counts lines of code
cloc --vcs git --by-file --csv --quiet --unix --report-file=/data/hotspots/lines_by_file.csv --exclude-dir=coverage,3rdParty,SqlCompare,.vscode,packages,node_modules,bin,test-bin,_webtests,lib,services,web,obj,bower_components,WebTestSolution,dist

# removes last line that contains the SUM
head -n -1 /data/hotspots/lines_by_file.csv > /data/hotspots/temp.txt ; mv /data/hotspots/temp.txt /data/hotspots/lines_by_file.csv

# calculates frequencies
cd /usr/src/code-analysys
java -jar code-maat/app-standalone.jar -l /data/hotspots/git.log -c git2 -a revisions > /data/hotspots/frequencies.csv

# data normalization
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

# put together frequencies and complexity size
python maat-scripts/merge/merge_comp_freqs.py /data/hotspots/frequencies.csv /data/hotspots/lines_by_file.csv > /data/hotspots/freq_complexity.csv

# claculates hotspots for enclosed diagrams
python maat-scripts/transform/csv_as_enclosure_json.py --structure /data/hotspots/lines_by_file.csv --weights /data/hotspots/frequencies.csv > /data/hotspots/hotspots.json
