FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends netdata \
    && rm -rf /var/lib/apt/lists/*

COPY conf/netdata.conf /etc/netdata/netdata.conf

ENTRYPOINT [ "netdata", "-D" ]
