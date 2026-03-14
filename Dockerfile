FROM crystallang/crystal:latest-alpine AS builder

WORKDIR /src
COPY shard.yml shard.lock ./
RUN shards install --production

COPY src/ src/
RUN crystal build src/main.cr -o /usr/local/bin/ark \
    --release --no-debug --static \
    && strip /usr/local/bin/ark

FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata \
    && adduser -D -h /home/ark ark
COPY --from=builder /usr/local/bin/ark /usr/local/bin/ark
USER ark
ENTRYPOINT ["ark"]
