# Ark

A Slack gateway for AWS Bedrock Agents via Socket Mode. Ark connects Slack conversations to a Bedrock Agent using WebSocket (no public endpoint needed), forwards messages, and posts streamed responses back.

- **Direct messages** - the bot responds in a flat conversation
- **Channel mentions** - the bot responds in a thread

Slack thread timestamps are used as Bedrock session IDs, so follow-up messages in the same thread maintain conversation context.

## Prerequisites

- Crystal 1.10+
- A Slack app with Socket Mode enabled and scopes: `app_mentions:read`, `chat:write`, `im:history`, `reactions:write`
- An AWS Bedrock Agent with an alias
- AWS credentials with Bedrock access (and optionally Firehose)

## Configuration

All configuration is via environment variables:

| Variable | Required | Description |
|---|---|---|
| `SLACK_BOT_TOKEN` | yes | Slack bot user OAuth token (`xoxb-...`) |
| `SLACK_APP_TOKEN` | yes | Slack app-level token for Socket Mode (`xapp-...`) |
| `BEDROCK_AGENT_ID` | yes | AWS Bedrock Agent ID |
| `BEDROCK_AGENT_ALIAS_ID` | yes | AWS Bedrock Agent Alias ID |
| `AWS_PROFILE` | * | AWS profile name from `~/.aws/credentials` |
| `AWS_ACCESS_KEY_ID` | * | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | * | AWS secret key |
| `AWS_SESSION_TOKEN` | no | AWS session token (for temporary credentials) |
| `AWS_REGION` | no | AWS region (default: `us-east-1`, or from profile config) |
| `FIREHOSE_STREAM_NAME` | no | Kinesis Firehose delivery stream for analytics |
| `LOG_LEVEL` | no | Log level: `debug`, `info`, `warn`, `error` (default: `info`) |

\* Either `AWS_PROFILE` or both `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` must be set. Explicit keys take priority over profile. When using `AWS_PROFILE`, credentials are read from `~/.aws/credentials` and region from `~/.aws/config`.

## Development

```sh
cp .env.example .env  # fill in your values
make build            # debug binary
make test             # run specs
make lint             # run ameba
make format           # format source
```

Environment variables in your shell take precedence over `.env` values.

## Docker

```sh
docker build -t ark .
docker run -e SLACK_BOT_TOKEN=... -e SLACK_APP_TOKEN=... \
  -e BEDROCK_AGENT_ID=... -e BEDROCK_AGENT_ALIAS_ID=... \
  -e AWS_ACCESS_KEY_ID=... -e AWS_SECRET_ACCESS_KEY=... \
  ark
```

The image uses a multi-stage build (Crystal Alpine -> Alpine) with a static binary.

## Project structure

```
src/
  main.cr                     # Entry point, config, signal handling
  ark/
    gateway.cr                # Slack Socket Mode event loop
    config.cr                 # Environment variable configuration
    slack/
      client.cr               # Slack Web API client
      socket_mode.cr          # Socket Mode WebSocket connection
      mrkdwn.cr               # Markdown -> Slack mrkdwn conversion
      block_kit.cr            # Block Kit table support
      types.cr                # Constants and MIME type mapping
    bedrock/
      agent.cr                # Bedrock Agent client
      event_stream.cr         # AWS binary event stream decoder
      session.cr              # Session ID utilities
      types.cr                # Request/response types
    aws/
      signer.cr               # AWS SigV4 signing (via awscr-signer)
      credentials.cr          # AWS credential struct
      firehose.cr             # Kinesis Firehose analytics publisher
```
