package bitrise

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseBitrise(t *testing.T) {
	testCases := []struct {
		name        string
		yamlContent string
		validate    func(*testing.T, *BitriseYML)
		expectError bool
	}{
		{
			name: "basic workflow",
			yamlContent: `
format_version: 13
default_step_lib: https://github.com/bitrise-io/bitrise-steplib.git
workflows:
  primary:
    steps:
    - activate-ssh-key@4:
        run_if: '{{getenv "SSH_RSA_PRIVATE_KEY" | ne ""}}'
    - git-clone@8: {}
    - script@1:
        title: Hello World
        inputs:
        - content: |
            #!/bin/bash
            echo "Hello World!"
`,
			validate: func(t *testing.T, config *BitriseYML) {
				if config.FormatVersion != "13" {
					t.Errorf("expected format_version '13', got '%s'", config.FormatVersion)
				}
				if len(config.Workflows) != 1 {
					t.Errorf("expected 1 workflow, got %d", len(config.Workflows))
				}
				workflow, exists := config.Workflows["primary"]
				if !exists {
					t.Error("expected workflow 'primary' to exist")
				}
				if len(workflow.Steps) != 3 {
					t.Errorf("expected 3 steps, got %d", len(workflow.Steps))
				}
			},
		},
		{
			name: "workflow with environment variables",
			yamlContent: `
format_version: 13
default_step_lib: https://github.com/bitrise-io/bitrise-steplib.git
app:
  envs:
  - BITRISE_PROJECT_PATH: MyApp.xcworkspace
  - BITRISE_SCHEME: MyApp
workflows:
  test:
    envs:
    - TEST_ENV: test_value
    steps:
    - script@1:
        inputs:
        - content: echo $TEST_ENV
`,
			validate: func(t *testing.T, config *BitriseYML) {
				if len(config.App.Envs) != 2 {
					t.Errorf("expected 2 app envs, got %d", len(config.App.Envs))
				}
				workflow := config.Workflows["test"]
				if len(workflow.Envs) != 1 {
					t.Errorf("expected 1 workflow env, got %d", len(workflow.Envs))
				}
			},
		},
		{
			name: "workflow with triggers",
			yamlContent: `
format_version: 13
default_step_lib: https://github.com/bitrise-io/bitrise-steplib.git
trigger_map:
- push_branch: main
  workflow: primary
- pull_request_source_branch: "*"
  workflow: pull_request
  is_pull_request_allowed: true
workflows:
  primary:
    steps:
    - git-clone@8: {}
  pull_request:
    steps:
    - git-clone@8: {}
`,
			validate: func(t *testing.T, config *BitriseYML) {
				if len(config.Trigger) != 2 {
					t.Errorf("expected 2 triggers, got %d", len(config.Trigger))
				}
				if config.Trigger[0].Workflow != "primary" {
					t.Errorf("expected first trigger workflow 'primary', got '%s'", config.Trigger[0].Workflow)
				}
				if !config.Trigger[1].IsPullRequestAllowed {
					t.Error("expected second trigger to allow pull requests")
				}
			},
		},
		{
			name: "pipeline with stages",
			yamlContent: `
format_version: 13
default_step_lib: https://github.com/bitrise-io/bitrise-steplib.git
pipelines:
  main-pipeline:
    stages:
    - build-stage: {}
    - test-stage:
        should_always_run: "false"
        abort_on_fail: "true"
stages:
  build-stage:
    workflows:
    - build-ios: {}
    - build-android: {}
  test-stage:
    workflows:
    - test-unit: {}
    - test-integration:
        run_if: '{{getenv "RUN_INTEGRATION_TESTS" | eq "true"}}'
workflows:
  build-ios:
    steps:
    - xcode-build@1: {}
  build-android:
    steps:
    - gradle-build@1: {}
  test-unit:
    steps:
    - script@1: {}
  test-integration:
    steps:
    - script@1: {}
`,
			validate: func(t *testing.T, config *BitriseYML) {
				if len(config.Pipelines) != 1 {
					t.Errorf("expected 1 pipeline, got %d", len(config.Pipelines))
				}
				pipeline := config.Pipelines["main-pipeline"]
				if len(pipeline.Stages) != 2 {
					t.Errorf("expected 2 stages in pipeline, got %d", len(pipeline.Stages))
				}
				if len(config.Stages) != 2 {
					t.Errorf("expected 2 stage definitions, got %d", len(config.Stages))
				}
				buildStage := config.Stages["build-stage"]
				if len(buildStage.Workflows) != 2 {
					t.Errorf("expected 2 workflows in build-stage, got %d", len(buildStage.Workflows))
				}
			},
		},
		{
			name: "workflow with before_run and after_run",
			yamlContent: `
format_version: 13
default_step_lib: https://github.com/bitrise-io/bitrise-steplib.git
workflows:
  setup:
    steps:
    - script@1:
        title: Setup
  cleanup:
    steps:
    - script@1:
        title: Cleanup
  main:
    before_run:
    - setup
    after_run:
    - cleanup
    steps:
    - script@1:
        title: Main Task
`,
			validate: func(t *testing.T, config *BitriseYML) {
				if len(config.Workflows) != 3 {
					t.Errorf("expected 3 workflows, got %d", len(config.Workflows))
				}
				mainWorkflow := config.Workflows["main"]
				if len(mainWorkflow.BeforeRun) != 1 {
					t.Errorf("expected 1 before_run, got %d", len(mainWorkflow.BeforeRun))
				}
				if len(mainWorkflow.AfterRun) != 1 {
					t.Errorf("expected 1 after_run, got %d", len(mainWorkflow.AfterRun))
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
			configPath := filepath.Join(tempDir, "bitrise.yml")
			
			if err := os.WriteFile(configPath, []byte(tc.yamlContent), 0644); err != nil {
				t.Fatalf("failed to write test file: %v", err)
			}

			config, err := ParseBitrise(configPath)
			
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
				tc.validate(t, config)
			}
		})
	}
}

func TestParseBitrise_FileNotFound(t *testing.T) {
	_, err := ParseBitrise("/non/existent/file.yml")
	if err == nil {
		t.Error("expected error for non-existent file")
	}
}