# Testing

Ark uses Crystal's built-in spec framework with mock-based testing.

## Running tests

```sh
# All tests
crystal spec

# Specific file
crystal spec spec/ark/gateway_spec.cr

# Specific test by line
crystal spec spec/ark/slack/mrkdwn_spec.cr:10
```

## Test structure

Tests mirror the source structure:

```
spec/
├── spec_helper.cr              # Common setup, logging disabled
└── ark/
    ├── config_spec.cr          # Configuration loading
    ├── gateway_spec.cr         # Event routing and response flow
    ├── aws/
    │   ├── credentials_spec.cr # Profile parsing, credential resolution
    │   └── firehose_spec.cr    # Event serialization
    ├── bedrock/
    │   ├── event_stream_spec.cr # Binary protocol decoding
    │   └── session_spec.cr     # Session ID sanitization
    └── slack/
        ├── block_kit_spec.cr   # Table parsing and Block Kit rendering
        ├── mrkdwn_spec.cr      # Markdown to mrkdwn conversion
        └── types_spec.cr       # MIME type resolution
```

## Mock architecture

The gateway spec uses test doubles for all dependencies:

- **`MockSlackAPI`** — records all API calls (messages, reactions, file uploads)
- **`MockAgent`** — returns configurable responses, tracks invocations
- **`MockPublisher`** — records published analytics events
- **`MockSocketMode`** — allows simulating incoming events via `simulate_event()`

This enables testing the full message flow without network calls.

## Writing tests

### Unit tests

Most modules have pure functions that are easy to test:

```crystal
describe Ark::Slack::Mrkdwn do
  it "converts bold markdown" do
    Ark::Slack::Mrkdwn.convert("**hello**").should eq("*hello*")
  end
end
```

### Gateway integration tests

Use the mock infrastructure to test end-to-end flows:

```crystal
it "responds to direct messages" do
  _, slack_api, socket_mode, agent, _ = build_gateway

  socket_mode.simulate_event(dm_event("U999", "hello"))
  Fiber.yield

  agent.invocations.size.should eq(1)
  slack_api.messages.size.should eq(1)
end
```

The `Fiber.yield` call ensures spawned fibers (reactions, analytics) have a chance to execute.

## CI

Tests run automatically on push and PRs via GitHub Actions. See `.github/workflows/ci.yml`.
