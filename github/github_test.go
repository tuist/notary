package github

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseWorkflow(t *testing.T) {
	testCases := []struct {
		name        string
		yamlContent string
		validate    func(*testing.T, *Workflow)
		expectError bool
	}{
		{
			name: "basic workflow",
			yamlContent: `
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: go test ./...
`,
			validate: func(t *testing.T, w *Workflow) {
				if w.Name != "CI" {
					t.Errorf("expected workflow name 'CI', got '%s'", w.Name)
				}
				if len(w.Jobs) != 1 {
					t.Errorf("expected 1 job, got %d", len(w.Jobs))
				}
				job, exists := w.Jobs["test"]
				if !exists {
					t.Error("expected job 'test' to exist")
				}
				if len(job.Steps) != 2 {
					t.Errorf("expected 2 steps, got %d", len(job.Steps))
				}
			},
		},
		{
			name: "workflow with environment variables",
			yamlContent: `
name: Build
on: push
env:
  GO_VERSION: "1.21"
jobs:
  build:
    runs-on: ubuntu-latest
    env:
      CGO_ENABLED: "0"
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: go build
        env:
          GOOS: linux
`,
			validate: func(t *testing.T, w *Workflow) {
				if w.Env["GO_VERSION"] != "1.21" {
					t.Errorf("expected global env GO_VERSION='1.21', got '%s'", w.Env["GO_VERSION"])
				}
				job := w.Jobs["build"]
				if job.Env["CGO_ENABLED"] != "0" {
					t.Errorf("expected job env CGO_ENABLED='0', got '%s'", job.Env["CGO_ENABLED"])
				}
				if job.Steps[1].Env["GOOS"] != "linux" {
					t.Errorf("expected step env GOOS='linux', got '%s'", job.Steps[1].Env["GOOS"])
				}
			},
		},
		{
			name: "workflow with matrix strategy",
			yamlContent: `
name: Matrix Build
on: push
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        go: [1.20, 1.21]
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: ${{ matrix.go }}
`,
			validate: func(t *testing.T, w *Workflow) {
				job := w.Jobs["test"]
				if job.Strategy == nil {
					t.Error("expected strategy to be defined")
				}
				if job.Strategy.Matrix == nil {
					t.Error("expected matrix to be defined")
				}
			},
		},
		{
			name: "workflow with container",
			yamlContent: `
name: Container Build
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: golang:1.21
      env:
        FOO: bar
    steps:
      - uses: actions/checkout@v3
      - run: go build
`,
			validate: func(t *testing.T, w *Workflow) {
				job := w.Jobs["build"]
				if job.Container == nil {
					t.Error("expected container to be defined")
				}
				if job.Container.Image != "golang:1.21" {
					t.Errorf("expected container image 'golang:1.21', got '%s'", job.Container.Image)
				}
			},
		},
		{
			name: "workflow with job dependencies",
			yamlContent: `
name: Sequential Jobs
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building"
  test:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - run: echo "Testing"
  deploy:
    runs-on: ubuntu-latest
    needs: [build, test]
    steps:
      - run: echo "Deploying"
`,
			validate: func(t *testing.T, w *Workflow) {
				if len(w.Jobs) != 3 {
					t.Errorf("expected 3 jobs, got %d", len(w.Jobs))
				}
				testJob := w.Jobs["test"]
				if testJob.Needs == nil {
					t.Error("expected test job to have 'needs' defined")
				}
			},
		},
		{
			name:        "invalid YAML",
			yamlContent: `this is not valid yaml: [`,
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			tempDir := t.TempDir()
			workflowPath := filepath.Join(tempDir, "workflow.yml")
			
			if err := os.WriteFile(workflowPath, []byte(tc.yamlContent), 0644); err != nil {
				t.Fatalf("failed to write test file: %v", err)
			}

			workflow, err := ParseWorkflow(workflowPath)
			
			if tc.expectError {
				if err == nil {
					t.Error("expected error but got none")
				}
				return
			}
			
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			
			if tc.validate != nil {
				tc.validate(t, workflow)
			}
		})
	}
}

func TestParseWorkflow_FileNotFound(t *testing.T) {
	_, err := ParseWorkflow("/non/existent/file.yml")
	if err == nil {
		t.Error("expected error for non-existent file")
	}
}