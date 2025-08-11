# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Notary is a Go CLI tool that enables developers to define and run CI/CD pipelines locally in containers. Pipelines are defined as bash scripts with annotations in a `notary/` directory. The tool executes these scripts in containerized environments and cryptographically signs successful runs, providing verifiable proof of execution.

## Build and Development Commands

```bash
# Build the binary
go build -o notary

# Run tests
go test -v ./...

# Install dependencies
go mod download

# Update dependencies
go mod tidy

# Run the CLI without building
go run main.go [command]

# Install globally
go install

# Format code
go fmt ./...

# Run linter (requires golangci-lint)
golangci-lint run
```

## Architecture

The codebase is a Go CLI application using the Cobra framework for command handling. Key architectural components:

### Pipeline Model
- **Pipeline Scripts**: Bash scripts stored in `notary/` directory with annotation headers
- **Annotations**: Special comments at the top of scripts defining:
  - Container image requirements
  - Cache paths and strategies
  - Signing/verification requirements
  - Environment variables and secrets

### Command Structure
1. **run**: Executes pipeline scripts in containers
   - Scans `notary/` directory for pipeline scripts
   - Parses annotations from script headers
   - Spins up appropriate containers
   - Mounts cache directories
   - Executes scripts and captures output

2. **list**: Discovers and displays available pipelines in `notary/`

3. **sign**: Cryptographically signs successful pipeline runs
   - Creates verifiable proof of execution
   - Stores signatures for audit trail

### Execution Flow
1. Pipeline script is read and annotations parsed
2. Container environment is prepared based on annotations
3. Cache directories are mounted if specified
4. Script executes within container
5. Output is streamed and logged
6. On success, execution can be cryptographically signed

### Key Design Decisions
- Pipelines are simple bash scripts, making them portable and easy to understand
- Annotations provide declarative configuration without complex YAML
- Local container execution ensures reproducibility
- Cryptographic signatures provide verifiable proof of execution
- Cache management optimizes repeated runs