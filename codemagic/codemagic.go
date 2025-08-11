package codemagic

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type CodemagicYML struct {
	Workflows map[string]Workflow `yaml:"workflows"`
}

type Workflow struct {
	Name                string                 `yaml:"name"`
	MaxBuildDuration    int                    `yaml:"max_build_duration,omitempty"`
	InstanceType        string                 `yaml:"instance_type,omitempty"`
	Environment         Environment            `yaml:"environment,omitempty"`
	Cache               *Cache                 `yaml:"cache,omitempty"`
	Triggering          *Triggering            `yaml:"triggering,omitempty"`
	Scripts             []Script               `yaml:"scripts"`
	Artifacts           []string               `yaml:"artifacts,omitempty"`
	Publishing          *Publishing            `yaml:"publishing,omitempty"`
	IntegrationsPrepend []string               `yaml:"integrations_prepend,omitempty"`
	IntegrationsAppend  []string               `yaml:"integrations_append,omitempty"`
}

type Environment struct {
	Vars              map[string]string      `yaml:"vars,omitempty"`
	Groups            []string               `yaml:"groups,omitempty"`
	Xcode             string                 `yaml:"xcode,omitempty"`
	CocoaPods         string                 `yaml:"cocoapods,omitempty"`
	Flutter           string                 `yaml:"flutter,omitempty"`
	Ruby              string                 `yaml:"ruby,omitempty"`
	Node              string                 `yaml:"node,omitempty"`
	Npm               string                 `yaml:"npm,omitempty"`
	Java              string                 `yaml:"java,omitempty"`
	AndroidSDK        *AndroidSDK            `yaml:"android_sdk,omitempty"`
}

type AndroidSDK struct {
	PlatformToolsVersion string   `yaml:"platform_tools_version,omitempty"`
	BuildToolsVersion    string   `yaml:"build_tools_version,omitempty"`
	Platforms            []string `yaml:"platforms,omitempty"`
	Ndk                  string   `yaml:"ndk,omitempty"`
}

type Cache struct {
	Paths []string `yaml:"paths,omitempty"`
}

type Triggering struct {
	Events  []TriggerEvent `yaml:"events,omitempty"`
	Branch  BranchPattern  `yaml:"branch_patterns,omitempty"`
	Tag     TagPattern     `yaml:"tag_patterns,omitempty"`
	Cancel  CancelPolicy   `yaml:"cancel_previous_builds,omitempty"`
}

type TriggerEvent struct {
	Push        *PushEvent        `yaml:"push,omitempty"`
	PullRequest *PullRequestEvent `yaml:"pull_request,omitempty"`
	Tag         *TagEvent         `yaml:"tag,omitempty"`
}

type PushEvent struct {
	Branch  string `yaml:"branch,omitempty"`
	Include bool   `yaml:"include,omitempty"`
}

type PullRequestEvent struct {
	SourceBranch      string `yaml:"source_branch,omitempty"`
	TargetBranch      string `yaml:"target_branch,omitempty"`
	Include           bool   `yaml:"include,omitempty"`
	UpdateCancelLabel string `yaml:"update_cancel_label,omitempty"`
}

type TagEvent struct {
	Tag     string `yaml:"tag,omitempty"`
	Include bool   `yaml:"include,omitempty"`
}

type BranchPattern struct {
	Include []string `yaml:"include,omitempty"`
	Exclude []string `yaml:"exclude,omitempty"`
}

type TagPattern struct {
	Include []string `yaml:"include,omitempty"`
	Exclude []string `yaml:"exclude,omitempty"`
}

type CancelPolicy struct {
	OnPush        bool `yaml:"on_push,omitempty"`
	OnPullRequest bool `yaml:"on_pull_request,omitempty"`
}

type Script struct {
	Name           string `yaml:"name,omitempty"`
	Script         string `yaml:"script,omitempty"`
	IgnoreFailure  bool   `yaml:"ignore_failure,omitempty"`
}

func (s *Script) UnmarshalYAML(value *yaml.Node) error {
	if value.Kind == yaml.ScalarNode {
		s.Script = value.Value
		return nil
	}
	
	type scriptAlias Script
	var temp scriptAlias
	if err := value.Decode(&temp); err != nil {
		return err
	}
	*s = Script(temp)
	return nil
}

type Publishing struct {
	Email        *EmailPublishing        `yaml:"email,omitempty"`
	Slack        *SlackPublishing        `yaml:"slack,omitempty"`
	AppStoreConnect *AppStorePublishing  `yaml:"app_store_connect,omitempty"`
	GooglePlay   *GooglePlayPublishing   `yaml:"google_play,omitempty"`
	Firebase     *FirebasePublishing     `yaml:"firebase,omitempty"`
	Github       *GithubPublishing       `yaml:"github_releases,omitempty"`
}

type EmailPublishing struct {
	Recipients []string `yaml:"recipients"`
	Notify     NotifySettings `yaml:"notify,omitempty"`
}

type SlackPublishing struct {
	Channel string `yaml:"channel"`
	Notify  NotifySettings `yaml:"notify,omitempty"`
}

type AppStorePublishing struct {
	AuthType        string `yaml:"auth_type,omitempty"`
	ApiKey          string `yaml:"api_key,omitempty"`
	ApiIssuer       string `yaml:"api_issuer,omitempty"`
	SubmitToTestflight bool `yaml:"submit_to_testflight,omitempty"`
	BetaGroups      []string `yaml:"beta_groups,omitempty"`
	SubmitToAppStore bool `yaml:"submit_to_app_store,omitempty"`
	ReleaseTtype    string `yaml:"release_type,omitempty"`
	CancelPreviousSubmissions bool `yaml:"cancel_previous_submissions,omitempty"`
}

type GooglePlayPublishing struct {
	Credentials     string `yaml:"credentials,omitempty"`
	Track           string `yaml:"track,omitempty"`
	SubmitAsRraft   bool   `yaml:"submit_as_draft,omitempty"`
	InAppUpdatePriority int `yaml:"in_app_update_priority,omitempty"`
	RolloutFraction float64 `yaml:"rollout_fraction,omitempty"`
	ChangesNotSentForReview bool `yaml:"changes_not_sent_for_review,omitempty"`
}

type FirebasePublishing struct {
	FirebaseProject string   `yaml:"firebase_project,omitempty"`
	FirebaseToken   string   `yaml:"firebase_token,omitempty"`
	FirebaseGroups  []string `yaml:"firebase_groups,omitempty"`
	FirebaseReleaseNotes string `yaml:"firebase_release_notes,omitempty"`
	AppID           string   `yaml:"app_id,omitempty"`
}

type GithubPublishing struct {
	Prerelease  bool     `yaml:"prerelease,omitempty"`
	Artifacts   []string `yaml:"artifacts,omitempty"`
	Files       []string `yaml:"files,omitempty"`
	ReleaseNotes string   `yaml:"release_notes,omitempty"`
}

type NotifySettings struct {
	Success bool `yaml:"success,omitempty"`
	Failure bool `yaml:"failure,omitempty"`
}

func ParseCodemagic(path string) (*CodemagicYML, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read Codemagic config file: %w", err)
	}

	var config CodemagicYML
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse Codemagic YAML: %w", err)
	}

	return &config, nil
}