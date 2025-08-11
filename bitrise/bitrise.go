package bitrise

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type BitriseYML struct {
	FormatVersion string                   `yaml:"format_version"`
	DefaultStepLib string                  `yaml:"default_step_lib"`
	ProjectType   string                   `yaml:"project_type,omitempty"`
	Title         string                   `yaml:"title,omitempty"`
	Summary       string                   `yaml:"summary,omitempty"`
	Description   string                   `yaml:"description,omitempty"`
	App           App                      `yaml:"app,omitempty"`
	Trigger       []Trigger                `yaml:"trigger_map,omitempty"`
	Workflows     map[string]Workflow      `yaml:"workflows"`
	Pipelines     map[string]Pipeline      `yaml:"pipelines,omitempty"`
	Stages        map[string]Stage         `yaml:"stages,omitempty"`
	Meta          map[string]interface{}   `yaml:"meta,omitempty"`
}

type App struct {
	Envs []Env `yaml:"envs,omitempty"`
}

type Env struct {
	Key   string                 `yaml:"-"`
	Value string                 `yaml:"-"`
	Opts  map[string]interface{} `yaml:"opts,omitempty"`
}

func (e *Env) UnmarshalYAML(value *yaml.Node) error {
	var envMap map[string]interface{}
	if err := value.Decode(&envMap); err != nil {
		return err
	}
	
	for k, v := range envMap {
		if k == "opts" {
			if opts, ok := v.(map[string]interface{}); ok {
				e.Opts = opts
			}
		} else {
			e.Key = k
			if strVal, ok := v.(string); ok {
				e.Value = strVal
			} else {
				e.Value = fmt.Sprintf("%v", v)
			}
		}
	}
	return nil
}

type Trigger struct {
	Pattern    string `yaml:"-"`
	Workflow   string `yaml:"workflow,omitempty"`
	Pipeline   string `yaml:"pipeline,omitempty"`
	IsPullRequestAllowed bool `yaml:"is_pull_request_allowed,omitempty"`
}

func (t *Trigger) UnmarshalYAML(value *yaml.Node) error {
	var triggerMap map[string]interface{}
	if err := value.Decode(&triggerMap); err != nil {
		return err
	}
	
	for pattern, v := range triggerMap {
		t.Pattern = pattern
		if workflow, ok := v.(string); ok {
			t.Workflow = workflow
		} else if workflowMap, ok := v.(map[string]interface{}); ok {
			if w, exists := workflowMap["workflow"]; exists {
				t.Workflow = fmt.Sprintf("%v", w)
			}
			if p, exists := workflowMap["pipeline"]; exists {
				t.Pipeline = fmt.Sprintf("%v", p)
			}
			if pr, exists := workflowMap["is_pull_request_allowed"]; exists {
				if b, ok := pr.(bool); ok {
					t.IsPullRequestAllowed = b
				}
			}
		}
		break
	}
	return nil
}

type Workflow struct {
	Title       string   `yaml:"title,omitempty"`
	Summary     string   `yaml:"summary,omitempty"`
	Description string   `yaml:"description,omitempty"`
	BeforeRun   []Step   `yaml:"before_run,omitempty"`
	AfterRun    []Step   `yaml:"after_run,omitempty"`
	Steps       []Step   `yaml:"steps"`
	Envs        []Env    `yaml:"envs,omitempty"`
	Meta        map[string]interface{} `yaml:"meta,omitempty"`
}

type Pipeline struct {
	Stages []PipelineStage `yaml:"stages"`
	Envs   []Env          `yaml:"envs,omitempty"`
}

type PipelineStage struct {
	StageName        string `yaml:"-"`
	ShouldAlwaysRun  string `yaml:"should_always_run,omitempty"`
	AbortOnFail      string `yaml:"abort_on_fail,omitempty"`
}

func (ps *PipelineStage) UnmarshalYAML(value *yaml.Node) error {
	var stageMap map[string]interface{}
	if err := value.Decode(&stageMap); err != nil {
		return err
	}
	
	for name, opts := range stageMap {
		ps.StageName = name
		if optsMap, ok := opts.(map[string]interface{}); ok {
			if v, exists := optsMap["should_always_run"]; exists {
				ps.ShouldAlwaysRun = fmt.Sprintf("%v", v)
			}
			if v, exists := optsMap["abort_on_fail"]; exists {
				ps.AbortOnFail = fmt.Sprintf("%v", v)
			}
		}
		break
	}
	return nil
}

type Stage struct {
	Title       string                `yaml:"title,omitempty"`
	Workflows   []StageWorkflow       `yaml:"workflows"`
	Envs        []Env                `yaml:"envs,omitempty"`
}

type StageWorkflow struct {
	WorkflowName string `yaml:"-"`
	RunIf        string `yaml:"run_if,omitempty"`
}

func (sw *StageWorkflow) UnmarshalYAML(value *yaml.Node) error {
	if value.Kind == yaml.ScalarNode {
		sw.WorkflowName = value.Value
		return nil
	}
	
	var workflowMap map[string]interface{}
	if err := value.Decode(&workflowMap); err != nil {
		return err
	}
	
	for name, opts := range workflowMap {
		sw.WorkflowName = name
		if optsMap, ok := opts.(map[string]interface{}); ok {
			if v, exists := optsMap["run_if"]; exists {
				sw.RunIf = fmt.Sprintf("%v", v)
			}
		}
		break
	}
	return nil
}

type Step struct {
	ID     string                 `yaml:"-"`
	Config map[string]interface{} `yaml:"-"`
}

func (s *Step) UnmarshalYAML(value *yaml.Node) error {
	var stepMap map[string]interface{}
	if err := value.Decode(&stepMap); err != nil {
		return err
	}
	
	for id, config := range stepMap {
		s.ID = id
		if configMap, ok := config.(map[string]interface{}); ok {
			s.Config = configMap
		}
		break
	}
	return nil
}

func ParseBitrise(path string) (*BitriseYML, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read Bitrise config file: %w", err)
	}

	var config BitriseYML
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse Bitrise YAML: %w", err)
	}

	return &config, nil
}