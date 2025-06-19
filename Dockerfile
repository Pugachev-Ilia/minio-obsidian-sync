FROM alpine:3.18

RUN apk add --no-cache bash curl ca-certificates

RUN curl -fsSL https://dl.min.io/server/minio/release/linux-amd64/minio \
    -o /usr/bin/minio && chmod +x /usr/bin/minio

RUN curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc \
    -o /usr/bin/mc && chmod +x /usr/bin/mc

COPY init/init.sh /init.sh

RUN chmod +x /init.sh

ENTRYPOINT ["/usr/bin/minio", "server", "/data", "--console-address", ":9001"]
