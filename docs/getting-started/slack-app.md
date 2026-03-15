# Slack app setup

Ark connects to Slack via Socket Mode, which uses WebSocket instead of HTTP webhooks. This means you don't need a public URL or load balancer.

## Create the app

1. Go to [api.slack.com/apps](https://api.slack.com/apps) and click **Create new app**
2. Choose **From scratch**
3. Name your app (e.g., "Ark") and select your workspace

## Enable Socket Mode

1. In the left sidebar, go to **Socket Mode**
2. Toggle **Enable Socket Mode** on
3. Create an app-level token with the `connections:write` scope
4. Save the token — this is your `SLACK_APP_TOKEN` (starts with `xapp-`)

## Configure OAuth scopes

Go to **OAuth & Permissions** and add these **Bot Token Scopes**:

| Scope | Purpose |
|---|---|
| `app_mentions:read` | Receive messages when the bot is mentioned in channels |
| `chat:write` | Post responses back to Slack |
| `channels:history` | Read thread replies in public channels (for context restoration) |
| `im:history` | Read direct messages sent to the bot |
| `reactions:write` | Add the "eyes" reaction when processing a message |
| `files:read` | Download files attached to messages |
| `files:write` | Upload files returned by the agent |
| `users:read` | Fetch user info (name, timezone) for agent context |

## Subscribe to events

Go to **Event Subscriptions** and enable events. Add these **Bot Events**:

| Event | Purpose |
|---|---|
| `message.im` | Direct messages to the bot |
| `app_mention` | When someone @mentions the bot in a channel |

## Install the app

1. Go to **Install App** in the sidebar
2. Click **Install to Workspace** and authorize
3. Copy the **Bot User OAuth Token** — this is your `SLACK_BOT_TOKEN` (starts with `xoxb-`)

## Invite the bot to channels

The bot automatically responds to DMs. For channel mentions, invite it:

```
/invite @Ark
```

## Required tokens

After setup, you should have two tokens:

| Token | Env var | Format |
|---|---|---|
| Bot token | `SLACK_BOT_TOKEN` | `xoxb-...` |
| App-level token | `SLACK_APP_TOKEN` | `xapp-...` |
