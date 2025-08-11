# 📝 Notary

A tool that brings CI/CD pipelines from various platforms to your local development environment. Notary uses existing pipelines from Codemagic, Bitrise, GitHub Actions, CircleCI, and other CI/CD platforms as the source of truth, maps them to a unified Pipeline Intermediate Format (PIF), and executes them locally in containers.

## 🎯 Philosophy

We believe developers' environments are environments to trust, and powerful enough to take the role that CI company environments would take. By leveraging existing pipeline definitions from popular CI/CD platforms and converting them to a common intermediate format, Notary enables you to run workflows locally in containers, then sign off successful runs directly from your development machine.

It's a great solution if you are a small or medium scale company and want to save the costs of CI infrastructure while maintaining compatibility with industry-standard CI/CD platforms.

## 📦 Installation

Using mise:
```bash
mise use go:github.com/tuist/notary
```

Or install with Go:
```bash
go install github.com/tuist/notary@latest
```

Or clone and build from source:
```bash
git clone https://github.com/tuist/notary.git
cd notary
go build -o notary
```

## ⚙️ Requirements

- Go 1.21+
- GitHub CLI (for sign-off functionality)
- Git

## 📄 License

MIT License - See [LICENSE.md](LICENSE.md) for details
