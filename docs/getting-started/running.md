# Running Ark

## Local development

After [installing](installation.md) and [configuring](configuration.md):

```sh
# Build and run
make build
bin/ark
```

Or in one step:

```sh
crystal run src/main.cr
```

You should see:

```
INFO  starting ark region=us-east-1 agent=ABCDEFGHIJ
INFO  resolved bot identity: U1234567
INFO  socket mode: connected
```

## Verifying the connection

1. Open Slack and send a direct message to your bot
2. You should see an :eyes: reaction appear on your message
3. The bot responds with the Bedrock Agent's reply

For channel mentions:

```
@Ark what is our refund policy?
```

The bot responds in a thread.

## Log levels

Set `LOG_LEVEL` to control verbosity:

| Level | What it shows |
|---|---|
| `debug` | Everything including Bedrock response sizes and internal state |
| `info` | Startup, connections, message processing |
| `warn` | File download issues, unsupported types, reaction failures |
| `error` | Agent invoke failures, Firehose publish errors |

## Graceful shutdown

Ark handles `SIGINT` and `SIGTERM` for graceful shutdown:

```sh
# If running in foreground
Ctrl+C

# If running as a service
kill -TERM <pid>
```

## Health check

Ark doesn't expose an HTTP port (Socket Mode is outbound-only). To verify the process is healthy, check the logs or process status:

```sh
# Check if running
pgrep -f ark

# Watch logs
LOG_LEVEL=debug bin/ark
```
