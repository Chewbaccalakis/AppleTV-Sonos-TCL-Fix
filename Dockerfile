FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends adb ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["adb"]
CMD ["version"]