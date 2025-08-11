# 📝 Notary

A tool that enables developers to define and run CI/CD pipelines locally in containers, then cryptographically sign successful runs. Pipelines are simple bash scripts with annotations for containerization, caching, and signing requirements, stored in a `notary/` directory.

## 🎯 Philosophy

We believe developers' environments are environments to trust, and powerful enough to take the role that CI company environments would take. Notary lets you define pipelines as annotated bash scripts that run in containers locally, providing full control over your CI/CD process while maintaining cryptographic proof of successful executions.

It's a great solution if you are a small or medium scale company and want to save the costs of CI infrastructure while maintaining security and reproducibility.

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
