FROM ubuntu:22.04
RUN apt-get update && apt-get install -y git curl unzip xz-utils ca-certificates libglu1-mesa
RUN git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter --version
WORKDIR /workspaces/app
