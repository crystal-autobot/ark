# Message flow

This page traces a message from Slack through Ark and back.

## Direct message flow

```
User sends DM to bot
        │
        ▼
Socket Mode receives WebSocket message
        │
        ▼
Gateway.handle_events_api() extracts inner event
        │
        ▼
Gateway.handle_message() validates:
  - Not from the bot itself
  - Channel type is "im" (DM)
  - Subtype is nil or "file_share"
  - Text is non-empty or has files
        │
        ▼
Add :eyes: reaction (spawned fiber)
        │
        ▼
Download Slack files if attached (max 5, 10 MB each)
        │
        ▼
Gateway.respond():
  1. Look up user attributes (name, timezone, title) — cached
  2. Call agent.invoke() with:
     - Input text
     - Session ID (thread_ts, dots replaced with dashes)
     - User attributes + current_datetime
     - Input files (sent as CODE_INTERPRETER use case)
        │
        ▼
Bedrock::Agent builds signed POST request to:
  /agents/{agentId}/agentAliases/{aliasId}/sessions/{sessionId}/text
        │
        ▼
Parse streaming response (binary event stream):
  - "chunk" events → accumulate text + collect citations
  - "files" events → collect output files
        │
        ▼
Publish analytics event to Firehose (spawned fiber)
        │
        ▼
Format response:
  - If response contains markdown tables → Block Kit blocks
  - Otherwise → convert markdown to mrkdwn
  - Append source citations if present
  - Split long messages at paragraph boundaries (40k limit)
        │
        ▼
Post response to Slack channel/thread
        │
        ▼
Upload any output files returned by the agent
```

## Channel mention flow

The mention flow is similar with two differences:

1. The `<@BOT_ID>` mention is stripped from the text before forwarding
2. The response is always posted in a thread (using the message timestamp)

## Session management

Bedrock sessions are mapped to Slack threads:

| Slack context | Session ID |
|---|---|
| DM — first message | Message timestamp (e.g., `1710412200-123456`) |
| DM — thread reply | Thread timestamp |
| Channel — first mention | Message timestamp |
| Channel — thread reply | Thread timestamp |

The dot in Slack timestamps (e.g., `1710412200.123456`) is replaced with a dash for Bedrock compatibility.

## User context

Each message includes user attributes in the Bedrock session state:

| Attribute | Source |
|---|---|
| `current_datetime` | UTC ISO 8601 timestamp |
| `user_name` | Slack user's real name |
| `user_timezone` | Slack user's timezone |
| `user_title` | Slack user's profile title |

User info is cached per user ID for the lifetime of the process.

## File handling

### Input files (Slack to Bedrock)

- Max 5 files per message
- Max 10 MB per file
- MIME type resolved from Slack metadata, with extension-based fallback
- Sent to Bedrock as `CODE_INTERPRETER` use case with base64-encoded content
- Supported types: CSV, Excel, JSON, YAML, Word, HTML, Markdown, TXT, PDF, PNG

### Output files (Bedrock to Slack)

- Files returned by the agent (e.g., code interpreter output) are uploaded to the same Slack thread
- Uses `files.uploadV2` (get upload URL, upload content, complete)
