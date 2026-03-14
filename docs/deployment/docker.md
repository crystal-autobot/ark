# Docker deployment

Ark ships with a multi-stage Dockerfile that produces a small, static Alpine image.

## Build the image

```sh
docker build -t ark .
```

## Run

```sh
docker run \
  -e SLACK_BOT_TOKEN=xoxb-... \
  -e SLACK_APP_TOKEN=xapp-... \
  -e BEDROCK_AGENT_ID=... \
  -e BEDROCK_AGENT_ALIAS_ID=... \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  ark
```

On ECS with a task role, omit the AWS key variables — credentials are resolved automatically via the container metadata endpoint.

## Image details

| Property | Value |
|---|---|
| Base image | `alpine:3.19` |
| Build image | `crystallang/crystal:latest-alpine` |
| Binary | Statically linked, stripped |
| User | Non-root (`ark`) |
| Entrypoint | `ark` |

The final image is typically under 20 MB.

## Docker Compose

```yaml
services:
  ark:
    build: .
    restart: unless-stopped
    environment:
      SLACK_BOT_TOKEN: ${SLACK_BOT_TOKEN}
      SLACK_APP_TOKEN: ${SLACK_APP_TOKEN}
      BEDROCK_AGENT_ID: ${BEDROCK_AGENT_ID}
      BEDROCK_AGENT_ALIAS_ID: ${BEDROCK_AGENT_ALIAS_ID}
      AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
      AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
      AWS_REGION: ${AWS_REGION:-us-east-1}
      LOG_LEVEL: ${LOG_LEVEL:-info}
```
