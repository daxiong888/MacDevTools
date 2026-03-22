# Contributing to MacDevTools

Thanks for your interest in contributing to MacDevTools.

感谢你为 MacDevTools 做贡献！

## Ways to contribute

- Report bugs
- Propose features
- Improve scripts and compatibility
- Improve docs (README / examples / translations)

## Before you start

- Check existing issues and pull requests first.
- Keep changes focused and small.
- For script behavior changes, include clear reproduction/verification steps.

## Development setup

1. Fork and clone the repository.
2. Create a branch:
   - `feat/<short-name>` for features
   - `fix/<short-name>` for bug fixes
   - `docs/<short-name>` for documentation
3. Make your changes.
4. Test affected scripts on macOS where possible.

## Pull request checklist

- [ ] Scope is focused and related to one topic.
- [ ] Scripts run without syntax errors (`bash -n <script>.sh` where applicable).
- [ ] Documentation is updated if behavior/commands changed.
- [ ] No unrelated refactors or formatting-only changes.
- [ ] PR description includes: what changed, why, and how it was tested.

## Commit message examples

- `feat: add environment health check command`
- `fix: handle missing docker command gracefully`
- `docs: update homebrew install instructions`

## Coding guidelines

- Prefer simple, readable shell scripts.
- Keep behavior predictable and safe for cleanup commands.
- Avoid destructive defaults when uncertainty exists.
- Follow existing style in this repository.

## Reporting bugs (suggested template)

Please include:

- macOS version
- Shell (`bash`/`zsh`) and version
- Exact command run
- Expected vs actual behavior
- Relevant terminal output

## Need help?

Open an issue and provide context. We appreciate all contributions.
