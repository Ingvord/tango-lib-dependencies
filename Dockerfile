FROM debian:stretch-slim as buildenv

# Copy across files that are used to help orchestrate container compositions
# and test execution sequences
COPY wait-for-it.sh /usr/local/bin/wait-for-it.sh
COPY retry.sh /usr/local/bin/retry

RUN DOCKERHOST=`awk '/^[a-z]+[0-9]+\t00000000/ { printf("%d.%d.%d.%d", "0x" substr($3, 7, 2), "0x" substr($3, 5, 2), "0x" substr($3, 3, 2), "0x" substr($3, 1, 2)) }' < /proc/net/route` \
    && /usr/local/bin/wait-for-it.sh --host=$DOCKERHOST --port=3142 --timeout=3 --strict --quiet -- echo "Acquire::http::Proxy \"http://$DOCKERHOST:3142\";" > /etc/apt/apt.conf.d/30proxy \
    && echo "Proxy detected on docker host - using for this build" || echo "No proxy detected on docker host"

RUN ZEROMQ_VERSION=v4.2.2 \
    && buildDeps='git autoconf automake cmake build-essential ca-certificates curl libkrb5-dev libtool pkg-config unzip libzmq3-dev' \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get -y install $buildDeps --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /usr/src/zeromq \
    && git clone -b $ZEROMQ_VERSION https://github.com/zeromq/cppzmq.git /usr/src/zeromq \
    && cd /usr/src/zeromq \
    && cmake -H/usr/src/zeromq -B/usr/src/zeromq/build  -DCMAKE_INSTALL_PREFIX=/usr/local \
    && make -C /usr/src/zeromq/build -j$(nproc) \
    && make -C /usr/src/zeromq/build install \
    && apt-get purge -y --auto-remove $buildDeps \
    && rm -r /usr/src/zeromq

FROM debian:stretch-slim
COPY --from=buildenv /usr/local /usr/local