extends SceneTree

const AppScene := preload("res://scenes/app.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app = AppScene.instantiate()
	root.add_child(app)
	await process_frame
	app._show_world_setup()
	app._show_agent_setup()
	app._show_loading()
	await process_frame
	await process_frame
	assert(app.world != null)
	assert(app.world.simulation_paused)
	assert(app.world_viewport != null)
	assert(app.world.get_parent() == app.world_render_target)
	app._enter_world()
	await process_frame
	assert(not app.world.simulation_paused)
	assert(app.get_node("UI/SimulationHUD") != null)
	app.queue_free()
	quit()
