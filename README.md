# Notary

A tool to run GitHub and Forgejo Actions workflows locally in trusted developer environments and sign off commits using the GitHub CLI, drawing inspiration from [basecamp/gh-signoff](https://github.com/basecamp/gh-signoff).

## Philosophy

We believe developers' environments are environments to trust, and powerful enough to take the role that CI company environments would take. Notary enables you to run GitHub and Forgejo Actions workflows locally, then sign off successful runs directly from your development machine.

It's a great solution if you are a small or medium scale company and want to save the costs of CI infrastructure.

## Installation

```bash
go install github.com/tuist/notary@latest
```

Or clone and build from source:
```bash
git clone https://github.com/tuist/notary.git
cd notary
go build -o notary
```

## Usage

```bash
# List available workflows
notary list

# Run a specific workflow
notary run .github/workflows/test.yml

# Run default CI workflow
notary run

# Sign off a successful run with GitHub CLI
notary signoff
notary signoff -m "Custom sign-off message"
```

## Requirements

- Go 1.21+
- GitHub CLI (for sign-off functionality)
- Git

## License

MIT License - See [LICENSE.md](LICENSE.md) for details
