extends SceneTree

const AppScene := preload("res://scenes/app.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app = AppScene.instantiate()
	root.add_child(app)
	await process_frame
	assert(app.world == null) # The landing screen is shown before a world exists.
	assert(app.get_node("UI") != null)
	app.queue_free()
	quit()
