# Contributing

## Getting started

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes
4. Run checks: `make test && make lint && make format-check`
5. Commit with a [conventional commit](https://www.conventionalcommits.org/) message
6. Push and open a pull request

## Commit messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add support for Bedrock guardrails
fix: handle empty file attachments
refactor: extract session management from agent
docs: add ECS deployment guide
test: add specs for block kit table rendering
```

## Code style

- Use `crystal tool format` for formatting (2-space indent)
- Follow [ameba](https://github.com/crystal-ameba/ameba) linter rules
- Keep cyclomatic complexity under 10
- Use named constants instead of magic numbers
- Prefer early returns over deep nesting

## Pull request checklist

- [ ] All specs pass (`crystal spec`)
- [ ] No linter warnings (`./bin/ameba src/`)
- [ ] Code is formatted (`crystal tool format --check src/ spec/`)
- [ ] New features have specs
- [ ] Conventional commit message

## Architecture guidelines

- Keep the Gateway thin — business logic belongs in the modules it delegates to
- New AWS services should follow the same pattern: abstract class + implementation + null implementation
- Slack formatting logic goes in `Mrkdwn` or `BlockKit`, not in the Gateway
- Use Crystal's type system — prefer `String?` and pattern matching over runtime nil checks
