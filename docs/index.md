# Ark

A lightweight, high-performance Slack gateway for AWS Bedrock Agents.

Ark connects Slack conversations to an [AWS Bedrock Agent](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html) using WebSocket — no public endpoint or ingress is needed. When a message is received, it forwards the text to the agent and posts the streamed response back to Slack.

## Features

- **Direct messages** — the bot responds in a flat conversation
- **Channel mentions** — the bot responds in a thread
- **Conversation context** — thread timestamps are used as Bedrock session IDs, so follow-up messages maintain context
- **File support** — upload files in Slack and they're sent to the agent's code interpreter
- **Table rendering** — markdown tables in agent responses are rendered as Slack Block Kit tables
- **Citation sources** — knowledge base sources are displayed as a bulleted list
- **Analytics** — every interaction is optionally published to Kinesis Firehose for downstream analysis
- **AWS credential chain** — explicit keys, ECS task roles, or AWS CLI (SSO, assume-role)
- **Minimal footprint** — single static binary, under 20 MB memory, near-zero CPU at idle

## Quick start

```sh
# Install Crystal 1.10+
# Clone the repository
git clone https://github.com/crystal-autobot/ark.git
cd ark

# Install dependencies
shards install

# Configure
cp .env.example .env
# Edit .env with your Slack tokens, Bedrock agent ID, and AWS credentials

# Run
make build && bin/ark
```

See [Getting started](getting-started/installation.md) for the full setup guide.

## How it works

```
Slack (Socket Mode WS) ──> Ark Gateway ──> AWS Bedrock Agent
                              │
                              └──> AWS Firehose (optional analytics)
```

1. Ark connects to Slack via [Socket Mode](https://api.slack.com/apis/socket-mode) (WebSocket)
2. Incoming messages are forwarded to the configured Bedrock Agent via `InvokeAgent`
3. The streamed response is converted from markdown to Slack's mrkdwn format and posted back
4. Each interaction is optionally logged to Kinesis Firehose as newline-delimited JSON

## Built with

- [Crystal](https://crystal-lang.org) — fast, type-safe, compiled language
- [awscr-signer](https://github.com/taylorfinnell/awscr-signer) — AWS SigV4 request signing
- [AWS Bedrock Agent Runtime](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_agent-runtime_InvokeAgent.html) — agent invocation with streaming
