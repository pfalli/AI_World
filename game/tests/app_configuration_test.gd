extends SceneTree

const ExperimentConfigScript := preload("res://scripts/experiment_config.gd")

func _init() -> void:
	var config = ExperimentConfigScript.default_scenario()
	assert(config.agents.size() == 3)
	assert(config.agents[0].agent_name == "Alice")
	assert(config.agents[1].agent_name == "Bob")
	assert(float(config.agents[0].personality.sociability) > float(config.agents[1].personality.sociability))
	assert(float(config.agents[1].personality.selfishness) > float(config.agents[0].personality.selfishness))
	config.food_scarcity = "High"
	assert(config.food_amount() == 1)
	config.food_scarcity = "Medium"
	assert(config.food_amount() == 3)
	config.food_scarcity = "Low"
	assert(config.food_amount() == 5)
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/app.tscn")
	quit()
