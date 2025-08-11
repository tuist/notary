package github

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Workflow struct {
	Name string                 `yaml:"name"`
	On   interface{}            `yaml:"on"`
	Env  map[string]string      `yaml:"env,omitempty"`
	Jobs map[string]Job         `yaml:"jobs"`
}

type Job struct {
	Name        string            `yaml:"name,omitempty"`
	RunsOn      interface{}       `yaml:"runs-on"`
	Needs       interface{}       `yaml:"needs,omitempty"`
	If          string            `yaml:"if,omitempty"`
	Environment string            `yaml:"environment,omitempty"`
	Outputs     map[string]string `yaml:"outputs,omitempty"`
	Env         map[string]string `yaml:"env,omitempty"`
	Defaults    *Defaults         `yaml:"defaults,omitempty"`
	Steps       []Step            `yaml:"steps"`
	Strategy    *Strategy         `yaml:"strategy,omitempty"`
	Container   *Container        `yaml:"container,omitempty"`
	Services    map[string]Service `yaml:"services,omitempty"`
	TimeoutMinutes int            `yaml:"timeout-minutes,omitempty"`
	ContinueOnError bool          `yaml:"continue-on-error,omitempty"`
}

type Step struct {
	ID               string            `yaml:"id,omitempty"`
	Name             string            `yaml:"name,omitempty"`
	Uses             string            `yaml:"uses,omitempty"`
	Run              string            `yaml:"run,omitempty"`
	With             map[string]interface{} `yaml:"with,omitempty"`
	Env              map[string]string `yaml:"env,omitempty"`
	If               string            `yaml:"if,omitempty"`
	ContinueOnError  bool              `yaml:"continue-on-error,omitempty"`
	TimeoutMinutes   int               `yaml:"timeout-minutes,omitempty"`
	Shell            string            `yaml:"shell,omitempty"`
	WorkingDirectory string            `yaml:"working-directory,omitempty"`
}

type Defaults struct {
	Run *RunDefaults `yaml:"run,omitempty"`
}

type RunDefaults struct {
	Shell            string `yaml:"shell,omitempty"`
	WorkingDirectory string `yaml:"working-directory,omitempty"`
}

type Strategy struct {
	Matrix      map[string]interface{} `yaml:"matrix,omitempty"`
	FailFast    *bool                  `yaml:"fail-fast,omitempty"`
	MaxParallel int                    `yaml:"max-parallel,omitempty"`
}

type Container struct {
	Image       string            `yaml:"image"`
	Credentials *Credentials      `yaml:"credentials,omitempty"`
	Env         map[string]string `yaml:"env,omitempty"`
	Ports       []int             `yaml:"ports,omitempty"`
	Volumes     []string          `yaml:"volumes,omitempty"`
	Options     string            `yaml:"options,omitempty"`
}

type Service struct {
	Image       string            `yaml:"image"`
	Credentials *Credentials      `yaml:"credentials,omitempty"`
	Env         map[string]string `yaml:"env,omitempty"`
	Ports       []string          `yaml:"ports,omitempty"`
	Volumes     []string          `yaml:"volumes,omitempty"`
	Options     string            `yaml:"options,omitempty"`
}

type Credentials struct {
	Username string `yaml:"username,omitempty"`
	Password string `yaml:"password,omitempty"`
}

func ParseWorkflow(path string) (*Workflow, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read workflow file: %w", err)
	}

	var workflow Workflow
	if err := yaml.Unmarshal(data, &workflow); err != nil {
		return nil, fmt.Errorf("failed to parse workflow YAML: %w", err)
	}

	return &workflow, nil
}