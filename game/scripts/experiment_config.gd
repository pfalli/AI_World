class_name ExperimentConfig
extends Resource

@export var world_name := "Forest Experiment"
@export var environment := "Forest"
@export var simulation_speed := 1.0
@export var food_scarcity := "Low"
@export var map_size := "Standard" # Reserved for a future environment generator.
@export var weather := "Clear" # Reserved for future world conditions.
@export var resource_abundance := "Normal" # Reserved for future resource controls.
@export var agents: Array[AgentConfig] = []

static func default_scenario() -> ExperimentConfig:
	var config := ExperimentConfig.new()
	for index in range(3):
		config.agents.append(AgentConfig.defaults(index))
	return config

func food_amount() -> int:
	match food_scarcity:
		"High": return 1
		"Medium": return 3
		_: return 5
