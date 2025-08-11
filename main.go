package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

const version = "0.1.0"

type WorkflowConfig struct {
	Name string               `yaml:"name"`
	On   interface{}          `yaml:"on"`
	Jobs map[string]JobConfig `yaml:"jobs"`
}

type JobConfig struct {
	RunsOn string       `yaml:"runs-on"`
	Steps  []StepConfig `yaml:"steps"`
}

type StepConfig struct {
	Name string                 `yaml:"name"`
	Uses string                 `yaml:"uses"`
	Run  string                 `yaml:"run"`
	With map[string]interface{} `yaml:"with"`
	Env  map[string]string      `yaml:"env"`
}

var rootCmd = &cobra.Command{
	Use:     "notary",
	Short:   "Run GitHub and Forgejo Actions workflows locally",
	Long:    `Notary runs GitHub and Forgejo Actions workflows locally in trusted developer environments and enables signing off commits using the GitHub CLI.`,
	Version: version,
}

var runCmd = &cobra.Command{
	Use:   "run [workflow]",
	Short: "Run a workflow locally",
	Long:  `Run a GitHub or Forgejo Actions workflow locally in your development environment.`,
	Args:  cobra.MaximumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		workflowFile := ".github/workflows/ci.yml"
		if len(args) > 0 {
			workflowFile = args[0]
		}

		workflow, err := loadWorkflow(workflowFile)
		if err != nil {
			log.Fatalf("Failed to load workflow: %v", err)
		}

		fmt.Printf("🚀 Running workflow: %s\n", workflow.Name)

		for jobName, job := range workflow.Jobs {
			fmt.Printf("\n📦 Job: %s\n", jobName)
			if err := runJob(jobName, job); err != nil {
				log.Fatalf("Job %s failed: %v", jobName, err)
			}
		}

		fmt.Println("\n✅ Workflow completed successfully!")
	},
}

var signoffCmd = &cobra.Command{
	Use:   "signoff",
	Short: "Sign off the current commit",
	Long:  `Sign off the current commit using the GitHub CLI after successful local workflow execution.`,
	Run: func(cmd *cobra.Command, args []string) {
		message, _ := cmd.Flags().GetString("message")

		fmt.Println("📝 Signing off commit...")

		// Get the current commit SHA
		commitCmd := exec.Command("git", "rev-parse", "HEAD")
		commitOutput, err := commitCmd.Output()
		if err != nil {
			log.Fatalf("Failed to get current commit: %v", err)
		}
		commitSHA := string(commitOutput[:7]) // Short SHA

		// Use gh CLI to create a commit status
		ghCmd := exec.Command("gh", "api",
			fmt.Sprintf("repos/:owner/:repo/statuses/%s", commitSHA),
			"-f", "state=success",
			"-f", "context=notary/local",
			"-f", fmt.Sprintf("description=%s", message),
		)

		if output, err := ghCmd.CombinedOutput(); err != nil {
			fmt.Printf("⚠️  Failed to sign off with GitHub CLI: %v\n", err)
			fmt.Printf("Output: %s\n", output)
			fmt.Println("Make sure you have the GitHub CLI installed and authenticated.")
		} else {
			fmt.Printf("✅ Successfully signed off commit %s\n", commitSHA)
		}
	},
}

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List available workflows",
	Long:  `List all available GitHub Actions workflows in the repository.`,
	Run: func(cmd *cobra.Command, args []string) {
		workflowsDir := ".github/workflows"

		files, err := filepath.Glob(filepath.Join(workflowsDir, "*.yml"))
		yamlFiles, _ := filepath.Glob(filepath.Join(workflowsDir, "*.yaml"))
		files = append(files, yamlFiles...)

		if err != nil || len(files) == 0 {
			fmt.Println("No workflows found in .github/workflows/")
			return
		}

		fmt.Println("📋 Available workflows:")
		for _, file := range files {
			workflow, err := loadWorkflow(file)
			if err != nil {
				fmt.Printf("  ❌ %s (error loading)\n", filepath.Base(file))
				continue
			}
			fmt.Printf("  • %s - %s\n", filepath.Base(file), workflow.Name)
		}
	},
}

func init() {
	rootCmd.AddCommand(runCmd)
	rootCmd.AddCommand(signoffCmd)
	rootCmd.AddCommand(listCmd)

	signoffCmd.Flags().StringP("message", "m", "CI passed locally", "Sign-off message")
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func loadWorkflow(path string) (*WorkflowConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read workflow file: %w", err)
	}

	var workflow WorkflowConfig
	if err := yaml.Unmarshal(data, &workflow); err != nil {
		return nil, fmt.Errorf("failed to parse workflow: %w", err)
	}

	return &workflow, nil
}

func runJob(name string, job JobConfig) error {
	for i, step := range job.Steps {
		fmt.Printf("  Step %d/%d: %s\n", i+1, len(job.Steps), step.Name)

		if step.Run != "" {
			// Execute shell commands
			if err := runCommand(step.Run, step.Env); err != nil {
				return fmt.Errorf("step '%s' failed: %w", step.Name, err)
			}
		} else if step.Uses != "" {
			// Handle action references (simplified)
			fmt.Printf("    Using action: %s\n", step.Uses)
			if step.Uses == "actions/checkout@v4" || step.Uses == "actions/checkout@v3" {
				// Simulate checkout - in local env, we're already in the repo
				fmt.Println("    ✓ Repository already checked out (local)")
			} else {
				fmt.Printf("    ⚠️  Action %s would run in CI environment\n", step.Uses)
			}
		}
	}
	return nil
}

func runCommand(command string, env map[string]string) error {
	// Use sh to execute the command
	cmd := exec.Command("sh", "-c", command)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	// Set environment variables
	cmd.Env = os.Environ()
	for k, v := range env {
		cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", k, v))
	}

	return cmd.Run()
}
