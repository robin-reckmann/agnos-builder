# check=error=true

FROM ubuntu:24.04

ARG UNAME
ARG UID
ARG GID

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    android-sdk-libsparse-utils \
    bc \
    bison \
    build-essential \
    ccache \
    clangd \
    clang-format \
    debhelper-compat \
    flex \
    git \
    kmod \
    libcap2-bin \
    libdw-dev \
    libelf-dev \
    libssl-dev \
    openssl \
    python3 \
    python-is-python3 \
    rsync \
    && rm -rf /var/lib/apt/lists/*

RUN if [ ${UID:-0} -ne 0 ] && [ ${GID:-0} -ne 0 ]; then \
    userdel -r `getent passwd ${UID} | cut -d : -f 1` > /dev/null 2>&1; \
    groupdel -f `getent group ${GID} | cut -d : -f 1` > /dev/null 2>&1; \
    groupadd -g ${GID} -o ${UNAME} && \
    useradd -u $UID -g $GID ${UNAME} \
;fi

RUN CCACHE_PATH=$(which ccache) && \
    ln -s $CCACHE_PATH /usr/local/bin/gcc && \
    ln -s $CCACHE_PATH /usr/local/bin/g++ && \
    ln -s $CCACHE_PATH /usr/local/bin/cc && \
    ln -s $CCACHE_PATH /usr/local/bin/c++ && \
    ln -s $CCACHE_PATH /usr/local/bin/clang

ENTRYPOINT ["tail", "-f", "/dev/null"]
