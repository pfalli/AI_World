extends SceneTree

const WorldScene := preload("res://scenes/world.tscn")
const ExperimentConfigScript := preload("res://scripts/experiment_config.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config = ExperimentConfigScript.default_scenario()
	config.food_scarcity = "High"
	config.agents[0].agent_name = "Explorer Alice"
	config.agents[0].personality.sociability = 0.77
	config.agents.pop_back()
	var world = WorldScene.instantiate()
	world.configure(config)
	root.add_child(world)
	await process_frame
	assert(world.simulation_paused)
	assert(world.agents.get_child_count() == 2)
	assert(world.agents.get_child(0).agent_name == "Explorer Alice")
	assert(is_equal_approx(float(world.agents.get_child(0).personality.sociability), 0.77))
	assert(int(world.environment_entities["berry_bush_1"].berries_available) == 1)
	world.set_simulation_paused(false)
	assert(not world.simulation_paused)
	assert(not world.agents.get_child(0).simulation_paused)
	world.set_simulation_paused(true)
	assert(world.agents.get_child(0).simulation_paused)
	world.queue_free()
	quit()
