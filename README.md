# Notary

A tool to take control of CI costs and experience by moving CI to local development environments. Run pipelines locally and sign off commits using the GitHub CLI, drawing inspiration from [basecamp/gh-signoff](https://github.com/basecamp/gh-signoff).

## Philosophy

We believe developers' environments are environments to trust, and powerful enough to take the role that CI company environments would take. Notary provides a declarative layer to run CI locally for Swift Packages and Xcode projects.

It's a great solution if you are a small or medium scale company and want to save the costs of macOS CI.

## Installation

```bash
mise use spm:tuist/notary@latest
```

## License

MIT License - See [LICENSE.md](LICENSE.md) for details
