# Notary

A tool to run GitHub and Forgejo Actions workflows locally in trusted developer environments and sign off commits using the GitHub CLI, drawing inspiration from [basecamp/gh-signoff](https://github.com/basecamp/gh-signoff).

## Philosophy

We believe developers' environments are environments to trust, and powerful enough to take the role that CI company environments would take. Notary enables you to run GitHub and Forgejo Actions workflows locally for Swift Packages and Xcode projects, then sign off successful runs directly from your development machine.

It's a great solution if you are a small or medium scale company and want to save the costs of macOS CI.

## Installation

```bash
mise use spm:tuist/notary@latest
```

## License

MIT License - See [LICENSE.md](LICENSE.md) for details
