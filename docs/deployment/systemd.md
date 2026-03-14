# Systemd deployment

For running Ark on a server or Raspberry Pi, systemd provides process management with automatic restarts.

## Service file

Create `/etc/systemd/system/ark.service`:

```ini
[Unit]
Description=Ark - Slack Bedrock gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ark
Group=ark
WorkingDirectory=/opt/ark
ExecStart=/opt/ark/bin/ark
Restart=always
RestartSec=5
EnvironmentFile=/opt/ark/.env

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/opt/ark
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
```

## Setup

```sh
# Create service user
sudo useradd -r -s /sbin/nologin -d /opt/ark ark

# Deploy binary
sudo mkdir -p /opt/ark/bin
sudo cp bin/ark /opt/ark/bin/
sudo cp .env /opt/ark/.env
sudo chown -R ark:ark /opt/ark
sudo chmod 600 /opt/ark/.env

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable ark
sudo systemctl start ark
```

## Management

```sh
# Check status
sudo systemctl status ark

# View logs
sudo journalctl -u ark -f

# Restart
sudo systemctl restart ark

# Stop
sudo systemctl stop ark
```

## Updating

```sh
# Build new binary
make release

# Deploy
sudo systemctl stop ark
sudo cp bin/ark /opt/ark/bin/
sudo systemctl start ark
```
