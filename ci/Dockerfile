# Build for linux/amd64 — GitHub Actions runners are amd64.
# Self-contained: does not depend on the VS Code extension Docker image
# which was built on Apple Silicon (arm64).
FROM --platform=linux/amd64 python:3.11-slim

RUN pip install --no-cache-dir phenospy==0.272

# Apache Jena 5.2.0 (shacl, riot, update), ROBOT v1.9.5, Materializer v0.2.7
RUN apt-get update && apt-get install -y --no-install-recommends curl default-jre-headless \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://archive.apache.org/dist/jena/binaries/apache-jena-5.2.0.tar.gz \
       | tar -xz -C /opt \
    && ln -s /opt/apache-jena-5.2.0/bin/shacl  /usr/local/bin/shacl \
    && ln -s /opt/apache-jena-5.2.0/bin/riot   /usr/local/bin/riot \
    && ln -s /opt/apache-jena-5.2.0/bin/update /usr/local/bin/update \
    && curl -fsSL https://github.com/ontodev/robot/releases/download/v1.9.5/robot.jar \
       -o /usr/local/bin/robot.jar \
    && printf '#!/bin/sh\nexec java -jar /usr/local/bin/robot.jar "$@"\n' \
       > /usr/local/bin/robot \
    && chmod +x /usr/local/bin/robot \
    && curl -fsSL https://github.com/balhoff/materializer/releases/download/v0.2.7/materializer-0.2.7.tgz \
       | tar -xz -C /opt \
    && ln -s /opt/materializer-0.2.7/bin/materializer /usr/local/bin/materializer

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
