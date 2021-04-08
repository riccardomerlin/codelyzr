FROM clojure:alpine AS code-analysys
VOLUME /data

RUN apk update && \
    apk add git

# install cloc - counts lines of code
RUN apk update && \
    apk add cloc

# install phyton
RUN apk update && \
    apk add python2

ARG dest=/usr/src/code-analysys

RUN mkdir -p $dest

# install code-maat
ARG codemaatdest=/usr/src/code-analysys/code-maat

RUN mkdir -p $codemaatdest
WORKDIR $codemaatdest
COPY code-maat/project.clj $codemaatdest
RUN lein deps
COPY code-maat/ $codemaatdest
RUN mv "$(lein uberjar | sed -n 's/^Created \(.*standalone\.jar\)/\1/p')" app-standalone.jar

WORKDIR $dest

RUN mkdir -p maat-scripts
COPY maat-scripts/ ./maat-scripts/
COPY code-analysis.sh .

# ENTRYPOINT ["bash", "code-analysis.sh"]
# CMD []
CMD ["bash", "code-analysis.sh"]