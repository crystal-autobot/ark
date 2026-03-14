# ECS deployment

Ark runs well as an ECS service since it's a long-running process with no inbound ports.

## Task definition

```json
{
  "family": "ark",
  "requiresCompatibilities": ["EC2"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "ark",
      "image": "ghcr.io/crystal-autobot/ark:latest",
      "essential": true,
      "secrets": [
        { "name": "SLACK_BOT_TOKEN", "valueFrom": "arn:aws:ssm:...:parameter/ark/slack-bot-token" },
        { "name": "SLACK_APP_TOKEN", "valueFrom": "arn:aws:ssm:...:parameter/ark/slack-app-token" },
        { "name": "BEDROCK_AGENT_ID", "valueFrom": "arn:aws:ssm:...:parameter/ark/bedrock-agent-id" },
        { "name": "BEDROCK_AGENT_ALIAS_ID", "valueFrom": "arn:aws:ssm:...:parameter/ark/bedrock-alias-id" }
      ],
      "environment": [
        { "name": "AWS_REGION", "value": "us-east-1" },
        { "name": "LOG_LEVEL", "value": "info" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ark",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ark"
        }
      }
    }
  ]
}
```

## Service configuration

Since Ark uses Socket Mode (outbound WebSocket only), no load balancer or target group is needed:

- **Launch type**: EC2 or Fargate
- **Desired count**: 1 (only one instance should run to avoid duplicate responses)
- **Health check**: Process-level (ECS monitors the container)
- **No load balancer** required

!!! warning "Single instance only"
    Run exactly one instance. Multiple instances would cause duplicate responses since each connects independently to Slack.

## IAM task role

The task role needs Bedrock invoke permissions and optionally Firehose:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "bedrock:InvokeAgent",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "firehose:PutRecord",
      "Resource": "arn:aws:firehose:*:*:deliverystream/ark-*"
    }
  ]
}
```

When running on ECS with a task role, you don't need `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`. Ark reads the ECS container metadata endpoint (`AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`) automatically to resolve task role credentials.

## Resource requirements

Ark is lightweight:

- **CPU**: 256 units (0.25 vCPU) is sufficient
- **Memory**: 128-512 MB depending on file handling volume
- **Network**: Outbound HTTPS only (no inbound ports)
- **Storage**: No persistent storage needed
