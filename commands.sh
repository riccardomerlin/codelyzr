# *** GIT LOG ***
# from the beginning of time
# git log for gx and webtests
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames -- . ":(exclude)packges/*" ":(exclude)node_modules/*" ":(exclude)*/bower_components/*" ":(exclude)*/3rdParty/*" ":(exclude)*/bin/*" ":(exclude)*/test-bin/*" ":(exclude)*/obj/*" ":(exclude)dist/*"
# git log for gx only
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames -- . ":(exclude)packges/*" ":(exclude)node_modules/*" ":(exclude)*/bower_components/*" ":(exclude)*/3rdParty/*" ":(exclude)bin/*" ":(exclude)test-bin/*" ":(exclude)*/obj/*" ":(exclude)*/dist/*" ":(exclude)_webtests/*" ":(exclude)WebTestSolution/*" 

# from date
# git log for gx and webtests
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames --after=2019-05-19 -- . ":(exclude)packges/*" ":(exclude)node_modules/*" ":(exclude)*/bower_components/*" ":(exclude)*/3rdParty/*" ":(exclude)*/bin/*" ":(exclude)*/test-bin/*" ":(exclude)*/obj/*" ":(exclude)dist/*"
# git log for gx only
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames --after=2019-05-19 -- . ":(exclude)packges/*" ":(exclude)node_modules/*" ":(exclude)*/bower_components/*" ":(exclude)*/3rdParty/*" ":(exclude)*/bin/*" ":(exclude)*/test-bin/*" ":(exclude)*/obj/*" ":(exclude)dist/*" ":(exclude)_webtests/*" ":(exclude)WebTestSolution/*" 

# *** ANALYSIS ***
# frequencies 
git log --format=format: --name-only | grep -vE '^$' | sort | uniq -c | sort -r > all_frequencies.txt
# (possible NULL byte at the beginning, copy and paste data in a new file)
docker run -v C:/Users/riccardo.merlin/source/repos/Kneat/gx:/data -it code-maat-app -l /data/git.log -c git2 -a revisions

# code age
docker run -v C:/Users/riccardo.merlin/source/repos/Kneat/gx:/data -it code-maat-app -l /data/git.log -c git2 -a age

# *** CLOC ***
# lines by file # >>> remove final row with SUM !!!
cloc . --by-file --csv --quiet --unix --report-file=lines_by_file.csv --exclude-dir=coverage,3rdParty,SqlCompare,.vscode,packages,node_modules,bin,test-bin,_webtests,lib,services,web,obj,bower_components,WebTestSolution,dist

# lines by file from git ls # >>> remove final row with SUM !!!
cloc --vcs git --by-file --csv --quiet --unix --report-file=lines_by_file.csv --exclude-dir=coverage,3rdParty,SqlCompare,.vscode,packages,node_modules,bin,test-bin,_webtests,lib,services,web,obj,bower_components,WebTestSolution,dist
# clean up regex
# .*csproj.*\n
# .*package(-lock)?\.json.*\n
# .*yarn\.lock.*\n
# .*(app|Web|packages|Local)\.Config.*\n
# .*\.sln.*\n
# .*ChangeSchema.sql.*\n
# .*CHANGELOG.md.*\n
# .*MigrationsList.cs.*\n


# *** Merge Frequency and Complexity ***
python ../code-analysis/maat-scripts/merge/merge_comp_freqs.py frequencies.csv lines_by_file.csv > freq_complexity.csv

# *** D3 Graphs

# json for D3 hotspots
python ../code-analysis/maat-scripts/transform/csv_as_enclosure_json.py --structure lines_by_file.csv --weights frequencies.csv > hotspots.json
