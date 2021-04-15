Hot-spots analysis
=================

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

### Web server
In order to visualize enclosed diagrams for hotspots or complexity trends
there is a web server available that runs on nodeJs.

```bash
node server.js
```

It will run a local webserver that respond to http://localhost:9000
To visualize enclosed diagrams go to
```
http://localhost:9000/hotspots.html
```
To visualize complexity trends of the first 10 hotspots got to
```
http://localhost:9000/complexity-trends/complexity-file-trend.html?file=hotspot[number].html
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