# Ark

A lightweight, high-performance Slack gateway for AWS Bedrock Agents. Single static binary, under 20 MB memory, connects via Socket Mode (no public endpoint needed).

- **Direct messages** - the bot responds in a flat conversation
- **Channel mentions** - the bot responds in a thread

Slack thread timestamps are used as Bedrock session IDs, so follow-up messages in the same thread maintain conversation context. When a Bedrock session expires (1 hour idle), Ark automatically restores context from the Slack thread history.

## Prerequisites

- A Slack app with Socket Mode enabled and scopes: `app_mentions:read`, `channels:history`, `chat:write`, `files:read`, `files:write`, `im:history`, `reactions:write`, `users:read`
- An AWS Bedrock Agent with an alias

## Configuration

All configuration is via environment variables:

| Variable | Required | Description |
|---|---|---|
| `SLACK_BOT_TOKEN` | yes | Slack bot user OAuth token (`xoxb-...`) |
| `SLACK_APP_TOKEN` | yes | Slack app-level token for Socket Mode (`xapp-...`) |
| `BEDROCK_AGENT_ID` | yes | AWS Bedrock Agent ID |
| `BEDROCK_AGENT_ALIAS_ID` | yes | AWS Bedrock Agent Alias ID |
| `AWS_PROFILE` | no | AWS profile name (supports SSO, assume-role) |
| `AWS_ACCESS_KEY_ID` | no | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | no | AWS secret key |
| `AWS_SESSION_TOKEN` | no | AWS session token (for temporary credentials) |
| `AWS_REGION` | no | AWS region (default: `us-east-1`, or from profile config) |
| `FIREHOSE_STREAM_NAME` | no | Kinesis Firehose delivery stream for analytics |
| `SESSION_TTL_MINUTES` | no | Session staleness threshold in minutes (default: `55`, range: 1-60) |
| `LOG_LEVEL` | no | Log level: `debug`, `info`, `warn`, `error` (default: `info`) |

AWS credentials are resolved automatically: explicit keys > ECS task role > AWS CLI (SSO, assume-role, instance profile).

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
  ark
```

The image uses a multi-stage build (Crystal Alpine -> Alpine) with a static binary. Ark uses ~10 MB of memory and near-zero CPU at idle — it runs comfortably on the smallest instances (e.g., `t4g.nano`).

## Documentation

Full documentation is available at [crystal-autobot.github.io/ark](https://crystal-autobot.github.io/ark).
