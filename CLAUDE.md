# Ark

Slack gateway for AWS Bedrock Agents via Socket Mode.

## Code quality

- All code must pass `crystal spec` and `./bin/ameba` before committing
- Keep cyclomatic complexity under 10
- Use `crystal tool format` for formatting

## Verification checks

```sh
crystal spec
./bin/ameba src/
crystal tool format --check src/ spec/
make release
```
