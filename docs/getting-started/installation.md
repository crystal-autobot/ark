# Installation

## Prerequisites

- [Crystal](https://crystal-lang.org/install/) 1.10 or later
- A Slack workspace where you can install apps
- An AWS account with Bedrock access

## Install from source

```sh
git clone https://github.com/crystal-autobot/ark.git
cd ark
shards install
make build
```

This produces a debug binary at `bin/ark`.

For an optimized production binary:

```sh
make release
```

## Verify installation

```sh
bin/ark --version
```

## Next steps

Before running Ark, you need to:

1. [Create a Slack app](slack-app.md) with Socket Mode enabled
2. [Set up AWS](aws-setup.md) with a Bedrock Agent
3. [Configure](configuration.md) Ark with your tokens and credentials
