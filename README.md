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
docker run -v <full-path-of-local-git-repo>:/data code-analysis
```

Extras
------

### Interact with the docker container bash
```bash
docker run -v <full-path-of-local-git-repo>:/data --entry-point=/bin/bash code-analysis
```