# Development setup

## Prerequisites

- [Crystal](https://crystal-lang.org/install/) 1.10+
- Git

## Clone and install

```sh
git clone https://github.com/crystal-autobot/ark.git
cd ark
shards install
```

## Configure

```sh
cp .env.example .env
```

Edit `.env` with your Slack tokens and AWS credentials. See [Configuration](../getting-started/configuration.md) for details.

## Build and run

```sh
# Debug build
make build
bin/ark

# Or run directly
crystal run src/main.cr
```

## Available make targets

| Target | Description |
|---|---|
| `make build` | Build debug binary |
| `make release` | Build optimized binary |
| `make test` | Run specs |
| `make lint` | Run ameba linter |
| `make format` | Format source files |
| `make format-check` | Check formatting without changing files |
| `make docker` | Build Docker image |
| `make clean` | Remove build artifacts |
| `make help` | Show all targets |

## Code quality

Before committing, run:

```sh
make test          # 86 specs
make lint          # ameba linter
make format-check  # crystal formatter
```

All three must pass for CI to be green.
