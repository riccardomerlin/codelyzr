FROM node:22.9-alpine
VOLUME /data

# install cloc - counts lines of code
RUN apk add --no-cache cloc

RUN apk add --no-cache git
# trust repositories not owned by the current user https://github.blog/2022-04-18-highlights-from-git-2-36/#stricter-repository-ownership-checks
RUN git config --global --add safe.directory '*'

RUN apk add --no-cache python3
RUN apk add --no-cache curl
RUN apk add --no-cache bash
RUN apk add --no-cache openjdk11
RUN apk add --no-cache jq

# install clojure
RUN curl -O https://download.clojure.org/install/linux-install-1.10.3.822.sh
RUN chmod +x linux-install-1.10.3.822.sh
RUN ./linux-install-1.10.3.822.sh

# install Leiningen (Clojure compiler)
RUN curl -O https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
RUN chmod a+x lein
RUN mv ./lein /usr/bin
RUN lein

# create main dest folder
ARG dest=/usr/src/code-analysys

RUN mkdir -p $dest

# install maat-scripts
WORKDIR $dest
RUN git clone -b python3 https://github.com/adamtornhill/maat-scripts.git maat-scripts

# install code-maat
RUN git clone https://github.com/adamtornhill/code-maat.git code-maat
WORKDIR $dest/code-maat
RUN lein deps
RUN mv "$(lein uberjar | sed -n 's/^Created \(.*standalone\.jar\)/\1/p')" app-standalone.jar

# install git-miner
WORKDIR $dest
RUN git clone https://github.com/riccardomerlin/git-miner.git git-miner
WORKDIR $dest/git-miner
RUN npm ci
RUN npm install -g

WORKDIR $dest
# copy commands
COPY index.html .
COPY analysis-index.html .
COPY hotspots.html .
COPY complexity-file-trend.html .
COPY code-analysis.sh .
COPY server.js .
COPY analyses.json .

ENTRYPOINT ["bash", "code-analysis.sh"]
