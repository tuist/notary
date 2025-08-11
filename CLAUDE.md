# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Notary is a Go CLI tool that runs GitHub and Forgejo Actions workflows locally in trusted developer environments and signs off commits using the GitHub CLI. It enables developers to take control of CI costs by moving CI execution to local development machines.

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

The codebase is a single-file Go CLI application (`main.go`) using the Cobra framework for command handling. Key architectural components:

### Workflow Execution Model
- **WorkflowConfig**: Represents parsed GitHub/Forgejo Actions workflow YAML files
- **JobConfig**: Individual jobs within a workflow, containing multiple steps
- **StepConfig**: Individual steps that can either run shell commands (`run`) or reference actions (`uses`)

### Command Structure
1. **run**: Loads and executes workflow files locally
   - Default: `.github/workflows/ci.yml`
   - Executes `run` steps as shell commands
   - Recognizes checkout actions as no-ops (already in repo)
   - Other actions are noted but not executed

2. **list**: Discovers and displays available workflows in `.github/workflows/`

3. **signoff**: Creates GitHub commit status via GitHub CLI API
   - Uses `gh api` to post success status to commits
   - Requires GitHub CLI authentication

### Execution Flow
1. Workflow YAML is parsed into Go structs
2. Jobs are executed sequentially
3. Steps within jobs are executed in order
4. Shell commands inherit environment with step-specific env vars
5. Command output streams directly to stdout/stderr

### Key Design Decisions
- Actions beyond checkout are acknowledged but not executed locally
- The tool assumes it's running within the repository (no actual checkout needed)
- Sign-off uses GitHub's commit status API rather than actual commit signing
- Workflow execution stops on first failure