FROM debian:bookworm

RUN apt-get update \
    && apt-get install --no-install-recommends -y redis-server redis-tools \
    && rm -rf /var/lib/apt/lists/*



ENTRYPOINT  [ "redis-server", "--protected-mode", "no" ,\
	"--maxmemory", "256mb", "--maxmemory-policy", "allkeys-lru" ]
