# Native aarch64 so gen_snapshot can run inside sfosbuild.
# Oldest glibc that still has a working clang/python for the engine.
# The .so will load on Sailfish OS 5.1 (glibc 2.41).
FROM --platform=linux/arm64 debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
	ca-certificates \
	curl \
	git \
	python3 \
	python3-pkg-resources \
	python3-setuptools \
	python3-distutils \
	pkg-config \
	unzip \
	xz-utils \
	lsb-release \
	build-essential \
	sudo \
	procps \
	file \
	&& ln -sf /usr/bin/python3 /usr/local/bin/python \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Rarely changes; keep above the Flutter pin so version bumps do not reclone it.
RUN git clone --depth 1 --filter blob:none \
	https://chromium.googlesource.com/chromium/tools/depot_tools.git \
	/opt/depot_tools
ENV PATH=/opt/depot_tools:$PATH
ENV DEPOT_TOOLS_UPDATE=0
ENV GCLIENT_PY3=1

WORKDIR /opt

# Changing FLUTTER_VERSION / ENGINE_HASH rebuilds only this layer (gclient).
COPY sync.sh /usr/local/bin/sync-engine
RUN chmod +x /usr/local/bin/sync-engine
ARG FLUTTER_VERSION
ARG ENGINE_HASH
ARG FLUTTER_REPO=https://github.com/flutter/flutter.git
ENV FLUTTER_VERSION=$FLUTTER_VERSION \
	ENGINE_HASH=$ENGINE_HASH \
	FLUTTER_REPO=$FLUTTER_REPO \
	FLUTTER_ROOT=/opt/flutter
RUN /usr/local/bin/sync-engine

COPY build.sh /usr/local/bin/build-engine
RUN chmod +x /usr/local/bin/build-engine

ENTRYPOINT ["/usr/local/bin/build-engine"]
