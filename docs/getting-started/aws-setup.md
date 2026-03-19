# AWS setup

Ark requires an AWS Bedrock Agent and credentials with permission to invoke it.

## Bedrock Agent

### Create an agent

1. Open the [AWS Bedrock console](https://console.aws.amazon.com/bedrock/)
2. Go to **Agents** in the left sidebar
3. Click **Create agent**
4. Configure the agent with your desired model, instructions, and optionally a knowledge base
5. Create an **alias** for the agent (e.g., "production")

### Note the IDs

After creation, you need two values:

| Value | Where to find it | Env var |
|---|---|---|
| Agent ID | Agent details page | `BEDROCK_AGENT_ID` |
| Agent Alias ID | Agent alias tab | `BEDROCK_AGENT_ALIAS_ID` |

## AWS credentials

Ark supports two authentication methods:

### Option 1: AWS profile (recommended for local development)

Set `AWS_PROFILE` to a profile name from `~/.aws/credentials`:

```ini
# ~/.aws/credentials
[my-profile]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

# ~/.aws/config
[profile my-profile]
region = us-east-1
```

```sh
export AWS_PROFILE=my-profile
```

When using a profile, the region is automatically read from `~/.aws/config` unless `AWS_REGION` is explicitly set.

### Option 2: Explicit keys (recommended for deployment)

```sh
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
```

For temporary credentials (e.g., from STS AssumeRole), also set:

```sh
export AWS_SESSION_TOKEN=...
```

!!! note "Priority"
    Explicit keys always take priority over profile-based credentials.

## IAM permissions

The IAM user or role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "bedrock:InvokeAgent",
      "Resource": "arn:aws:bedrock:*:*:agent-alias/*/*"
    }
  ]
}
```

If using Firehose analytics, also add:

```json
{
  "Effect": "Allow",
  "Action": "firehose:PutRecord",
  "Resource": "arn:aws:firehose:*:*:deliverystream/*"
}
```

## Firehose analytics (optional)

Ark can publish structured analytics events to a Kinesis Firehose delivery stream as newline-delimited JSON, for downstream analysis with Athena, Glue, or S3.

When analytics is enabled, Bedrock Agent tracing is also enabled to extract metadata from agent responses (knowledge bases consulted, search queries, rationale). Raw user messages and agent responses are **not** stored — only structured metadata and message lengths.

To enable:

1. Create a Firehose delivery stream (e.g., with S3 destination)
2. Set `FIREHOSE_STREAM_NAME` to the stream name

If `FIREHOSE_STREAM_NAME` is not set, analytics and tracing are disabled silently.

### Event format

Each event is a JSON object:

```json
{
  "timestamp": "2026-03-14T10:30:00Z",
  "user_id": "U1234567",
  "thread_id": "1710412200-123456",
  "message_length": 32,
  "response_length": 485,
  "knowledge_bases": ["RJPTLAAPUC"],
  "sources": ["password-policy.pdf"],
  "action_groups": [],
  "search_queries": ["password length policy requirements"],
  "rationale": "The user is asking about password length requirements"
}
```

| Field | Description |
|---|---|
| `timestamp` | Event time (ISO 8601) |
| `user_id` | Slack user ID |
| `thread_id` | Slack thread timestamp (session ID) |
| `message_length` | User message byte size |
| `response_length` | Agent response byte size |
| `knowledge_bases` | Knowledge base IDs the agent consulted |
| `sources` | Source document names cited in the response |
| `action_groups` | Action groups invoked (e.g., CodeInterpreter) |
| `search_queries` | Search queries the agent issued to knowledge bases |
| `rationale` | Agent's preprocessing rationale (model-dependent, may be null) |
