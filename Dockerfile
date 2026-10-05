FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends adb tini python3-zeroconf \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --chmod=755 flush-cec.sh discover-tv.py ./

ENV TZ=Etc/UTC
ENV TV_PORT=5555
ENV TV_IP=""
ENV TV_NAME=""
ENV INTERVAL=900
ENV RETRY=60

ENTRYPOINT ["/usr/bin/tini", "--", "/app/flush-cec.sh"]