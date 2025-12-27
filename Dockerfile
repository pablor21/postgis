FROM postgres:18-alpine

LABEL maintainer="Pablo Ramirez <hello@pramirez.dev>"
LABEL description="Docker image with PostGIS extension for PostgreSQL."
LABEL version="1.0.0"

ENV POSTGIS_VERSION=3.6.1
ENV POSTGIS_SHA256=849391e75488a749663fbc8d63b846d063d387d286c04dea062820476f84c8f6

# Install PostGIS
RUN set -eux \
    && apk add --no-cache --virtual .fetch-deps \
        ca-certificates \
        openssl \
        tar \
    \
    && wget -O postgis.tar.gz "https://github.com/postgis/postgis/archive/${POSTGIS_VERSION}.tar.gz" \
    && echo "${POSTGIS_SHA256} *postgis.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/postgis \
    && tar \
        --extract \
        --file postgis.tar.gz \
        --directory /usr/src/postgis \
        --strip-components 1 \
    && rm postgis.tar.gz \
    \
    && apk add --no-cache --virtual .build-deps \
        gdal-dev \
        geos-dev \
        proj-dev \
        proj-util \
        sfcgal-dev \
        json-c-dev \
        libxml2-dev \
        perl \
        clang19 \
        llvm19 \
        g++ \
        make \
        pcre2-dev \
        protobuf-c-dev \
        autoconf \
        automake \
        libtool \
        gettext-dev \
    \
    && apk add --no-cache --virtual .build-deps-edge \
        --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing \
        --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
        gdal \
    \
    && cd /usr/src/postgis \
    && gettextize \
    && ./autogen.sh \
    && ./configure \
        --with-pcredir="$(pcre2-config --prefix)" \
    && make -j$(nproc) \
    && make install \
    \
    && apk add --no-cache --virtual .postgis-rundeps \
        gdal \
        geos \
        proj \
        sfcgal \
        json-c \
        libstdc++ \
        pcre2 \
        protobuf-c \
        libxml2 \
    && cd / \
    && rm -rf /usr/src/postgis \
    && apk del .fetch-deps .build-deps .build-deps-edge
# Clean up
RUN rm -rf /var/lib/apt/lists/*

