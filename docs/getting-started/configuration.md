# Configuration

All configuration is via environment variables. Ark also reads a `.env` file from the working directory if present (shell variables take precedence).

## Environment variables

### Required

| Variable | Description |
|---|---|
| `SLACK_BOT_TOKEN` | Slack bot user OAuth token (`xoxb-...`) |
| `SLACK_APP_TOKEN` | Slack app-level token for Socket Mode (`xapp-...`) |
| `BEDROCK_AGENT_ID` | AWS Bedrock Agent ID |
| `BEDROCK_AGENT_ALIAS_ID` | AWS Bedrock Agent Alias ID |

### AWS credentials (one of these is required)

| Variable | Description |
|---|---|
| `AWS_PROFILE` | Profile name from `~/.aws/credentials` |
| `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` | Explicit AWS keys |

Explicit keys take priority over profile. See [AWS setup](aws-setup.md) for details.

### Optional

| Variable | Default | Description |
|---|---|---|
| `AWS_SESSION_TOKEN` | — | AWS session token for temporary credentials |
| `AWS_REGION` | `us-east-1` | AWS region (overridden by profile config if using `AWS_PROFILE`) |
| `FIREHOSE_STREAM_NAME` | — | Kinesis Firehose stream for analytics (disabled if not set) |
| `LOG_LEVEL` | `info` | Log level: `debug`, `info`, `warn`, `error` |

## Example `.env` file

```sh
# Slack
SLACK_BOT_TOKEN=xoxb-1234567890-abcdef
SLACK_APP_TOKEN=xapp-1-A0B1C2D3E4-9876543210-xyz

# Bedrock Agent
BEDROCK_AGENT_ID=ABCDEFGHIJ
BEDROCK_AGENT_ALIAS_ID=TSTALIASID

# AWS credentials (option 1: profile)
AWS_PROFILE=my-profile

# AWS credentials (option 2: explicit keys)
# AWS_ACCESS_KEY_ID=AKIA...
# AWS_SECRET_ACCESS_KEY=...

# Optional
# AWS_REGION=us-east-1
# FIREHOSE_STREAM_NAME=ark-analytics
LOG_LEVEL=info
```

## Credential resolution order

1. If `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set, use them
2. If `AWS_PROFILE` is set, read credentials from `~/.aws/credentials`
3. If neither is set, Ark exits with an error

## Region resolution order

1. If `AWS_REGION` is set, use it
2. If `AWS_PROFILE` is set, read region from `~/.aws/config`
3. Fall back to `us-east-1`
