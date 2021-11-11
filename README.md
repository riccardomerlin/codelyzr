Codelyzr
========

Getting started
---------------

### Build docker image
```bash
docker build --tag code-analysis:latest .
```
### Run code analysis
```bash
docker run -v <full-path-of-local-git-repo>:/data -it code-analysis [start_date:optional]
```
`[start_date:optional]`: format YYYY-MM-DD, if specified it will restrict the
analysis starting from the specified date.

### Results
All results are saved in the `hotspots` folder in your local repo.

### Exclusions
It is possible to exclude some paths from the analysis if not relevant
so that the processing will take less time.
To specify what paths should be excluded, create the 
file `hotspots/.pathExclusions` and add one path to be excuded
per line.

Example:
```
dist/*
coverage/*
*/obj/*
```

In order to normalise data to detemine the top 10 hotspots,
non relevant files must be exluded.
To do so, create the file `hotspots/.fileExclusions`. This
uses regular expressions and you can add one regex per line.

Example:
```
clean up regex
.*csproj.*\n
.*package(-lock)?\.json.*\n
.*yarn\.lock.*\n
.*(app|Web|packages|Local)\.Config.*\n
.*\.sln.*\n
.*CHANGELOG.md.*\n
```

### Web server
In order to visualize enclosed diagrams for hotspots or complexity trends
there is a web server available that runs on nodeJs.

```bash
node server.js
```

It will run a local webserver that respond to http://localhost:9000
To visualize enclosed diagrams go to
```
http://localhost:9000/<ANALYSIS_FOLDER_PATH>/hotspots.html
```
To visualize complexity trends of the first 10 hotspots got to
```
http://localhost:9000/<ANALYSIS_FOLDER_PATH>/complexity-trends/complexity-file-trend.html?file=hotspot[number].html
```
where [number] ranges from 1 to 10.

Extras
------
### Interact with the docker container bash
You can run the container and execute individual commands on the local repo.
To access the container form bash use the following:
```bash
docker run -v <full-path-of-local-git-repo>:/data --entry-point=/bin/bash -it code-analysis
```
See [commands.sh](commands.sh) for the possible commands you can run.
