extends Node2D

var server_url := ""
@export var perception_radius := WorldConfig.PERCEPTION_RADIUS
var environment_entities: Dictionary = {}
var world_tick := 0
var _tick_seconds := 0.0
var _event_sequence := 0
var conversation_threads: Dictionary = {}
var selected_agent: WorldAgent
var _text_log: FileAccess
var _jsonl_log: FileAccess
@onready var agents: Node2D = $SimulationEntities/Agents
@onready var event_panel: TextEdit = $HUD/EventPanel
@onready var agent_panel: TextEdit = $HUD/AgentPanel
@onready var observer_camera: Camera2D = $ObserverCamera
@onready var ground: TileMapLayer = $VisualWorld/Ground
@onready var terrain: TileMapLayer = $VisualWorld/Terrain
@onready var decorations: Node2D = $VisualWorld/Decorations
var debug_visible := false
var log_visible := false
const GRASS_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/grass.png")
const WATER_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/grass_deep_water.png")
const TREE_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/trees.png")
const BUSH_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/bushes.png")
const STONE_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/stones.png")
const API_CONFIG := preload("res://scripts/api_config.gd")

func _ready() -> void:
	randomize()
	server_url = API_CONFIG.base_url()
	_build_visual_world()
	_build_resource_visuals()
	_open_simulation_logs()
	log_event("API base URL: %s" % server_url)
	_register_environment()
	for agent: WorldAgent in agents.get_children():
		agent.setup(self, server_url)
	log_event("World ready. Forest resources are available.")
	event_panel.visible = log_visible
	agent_panel.visible = false

func _exit_tree() -> void:
	if _text_log: _text_log.close()
	if _jsonl_log: _jsonl_log.close()

func _open_simulation_logs() -> void:
	# In the editor this resolves to <project>/../logs; it is created for every run.
	var log_directory := ProjectSettings.globalize_path("res://../logs")
	var directory_error := DirAccess.make_dir_recursive_absolute(log_directory)
	if directory_error != OK:
		push_warning("Could not create simulation log folder: %s" % log_directory)
		return
	_text_log = FileAccess.open(log_directory.path_join("simulation.log"), FileAccess.WRITE)
	_jsonl_log = FileAccess.open(log_directory.path_join("simulation.jsonl"), FileAccess.WRITE)
	if _text_log == null or _jsonl_log == null:
		push_warning("Could not open simulation log files in %s" % log_directory)
		return
	var started_at := Time.get_datetime_string_from_system()
	_text_log.store_line("AI World simulation started: %s" % started_at)
	_jsonl_log.store_line(JSON.stringify({"type": "simulation_started", "timestamp": started_at, "tick": world_tick}))
	_text_log.flush()
	_jsonl_log.flush()

func _process(delta: float) -> void:
	_tick_seconds += delta
	if _tick_seconds >= 1.0:
		world_tick += 1
		_tick_seconds = 0.0
		for agent: WorldAgent in agents.get_children(): agent.apply_needs()
	if selected_agent: show_agent_info(selected_agent)
	_update_camera(delta)
	_update_selection_indicator()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			debug_visible = not debug_visible
			for agent: WorldAgent in agents.get_children(): agent.set_debug_visible(debug_visible)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_L:
			log_visible = not log_visible
			event_panel.visible = log_visible
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89
		var next_zoom := clampf(observer_camera.zoom.x * factor, 0.75, 2.0)
		observer_camera.zoom = Vector2(next_zoom, next_zoom)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for agent: WorldAgent in agents.get_children():
			if agent.global_position.distance_to(get_global_mouse_position()) < 36.0:
				selected_agent = agent
				agent_panel.visible = true
				show_agent_info(agent)
				get_viewport().set_input_as_handled()
				return

func _update_camera(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Default UI actions include arrow keys; WASD is intentionally observer-only input.
	direction += Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if direction.length_squared() > 0.0:
		observer_camera.position += direction.normalized() * 440.0 * delta
		observer_camera.position.x = clampf(observer_camera.position.x, 240.0, 720.0)
		observer_camera.position.y = clampf(observer_camera.position.y, 160.0, 480.0)

func _update_selection_indicator() -> void:
	for agent: WorldAgent in agents.get_children():
		agent.get_node("SelectionIndicator").visible = agent == selected_agent

func _build_visual_world() -> void:
	var forest_tileset := TileSet.new()
	forest_tileset.tile_size = Vector2i(16, 16)
	var grass_source := TileSetAtlasSource.new()
	grass_source.texture = GRASS_TEXTURE
	grass_source.texture_region_size = Vector2i(16, 16)
	for y in range(4):
		for x in range(4): grass_source.create_tile(Vector2i(x, y))
	forest_tileset.add_source(grass_source, 0)
	var water_source := TileSetAtlasSource.new()
	water_source.texture = WATER_TEXTURE
	water_source.texture_region_size = Vector2i(16, 16)
	for y in range(16):
		for x in range(14): water_source.create_tile(Vector2i(x, y))
	forest_tileset.add_source(water_source, 1)
	ground.tile_set = forest_tileset
	terrain.tile_set = forest_tileset
	ground.collision_enabled = false
	terrain.collision_enabled = false
	var grass_cells: Array[Vector2i] = []
	for y in range(40):
		for x in range(60): grass_cells.append(Vector2i(x, y))
	for cell in grass_cells: ground.set_cell(cell, 0, Vector2i((cell.x + cell.y) % 4, (cell.x * 3 + cell.y) % 4))
	# A deterministic 12 x 8 oval around the existing logical water source at (720, 190).
	var pond_cells: Array[Vector2i] = []
	for y in range(8, 18):
		for x in range(38, 53):
			var dx := (x - 45.0) / 7.5
			var dy := (y - 12.5) / 4.7
			if dx * dx + dy * dy <= 1.0: pond_cells.append(Vector2i(x, y))
	for cell in pond_cells:
		# The provided deep-water atlas's 12:0 tile is its full-water interior.
		terrain.set_cell(cell, 1, Vector2i(12, 0))
	# The surrounding cells use the atlas's connected grass/water edge tile, creating a clean shore.
	for cell in pond_cells:
		for neighbor in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not pond_cells.has(cell + neighbor): terrain.set_cell(cell + neighbor, 1, Vector2i(0, 0))
	# Perimeter clusters are intentional decoration only; they create no simulation entities.
	for point in [Vector2(56, 88), Vector2(120, 104), Vector2(190, 72), Vector2(838, 76), Vector2(896, 124), Vector2(64, 492), Vector2(140, 548), Vector2(820, 520), Vector2(900, 474), Vector2(74, 288), Vector2(890, 286)]:
		_add_region_sprite(decorations, TREE_TEXTURE, point, Rect2(0, 0, 64, 64), Vector2(0, -32))
	for point in [Vector2(224, 132), Vector2(332, 410), Vector2(590, 110), Vector2(625, 488), Vector2(770, 404), Vector2(178, 455)]:
		_add_region_sprite(decorations, BUSH_TEXTURE, point, Rect2(0, 0, 16, 16), Vector2.ZERO)
	for point in [Vector2(724, 366), Vector2(754, 382), Vector2(784, 374), Vector2(808, 390)]:
		_add_region_sprite(decorations, STONE_TEXTURE, point, Rect2(0, 0, 32, 32), Vector2(0, -8))

func _build_resource_visuals() -> void:
	_add_region_sprite($SimulationEntities/Trees/Tree_1, TREE_TEXTURE, Vector2.ZERO, Rect2(0, 0, 64, 64), Vector2(0, -32))
	_add_region_sprite($SimulationEntities/BerryBushes/Berry_Bush_1, BUSH_TEXTURE, Vector2.ZERO, Rect2(0, 0, 16, 16), Vector2.ZERO)
	_add_region_sprite($SimulationEntities/Rocks/Rock_1, STONE_TEXTURE, Vector2.ZERO, Rect2(0, 0, 32, 32), Vector2(0, -8))

func _add_region_sprite(parent: Node, texture: Texture2D, position: Vector2, region: Rect2, offset: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.position = position + offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)

func build_observation(observer: WorldAgent) -> Dictionary:
	var entities: Array[Dictionary] = []
	var visible_ids: Array[String] = []
	for other: WorldAgent in agents.get_children():
		if other != observer and observer.global_position.distance_to(other.global_position) <= perception_radius:
			entities.append({"type": "agent", "id": other.agent_id, "name": other.agent_name})
			visible_ids.append(other.agent_id)
	for entity: Dictionary in environment_entities.values():
		var position := Vector2(float(entity.world_position.x), float(entity.world_position.y))
		var distance := observer.global_position.distance_to(position)
		if distance <= perception_radius:
			var affordances: Array[String] = []
			if entity.type == "berry_bush" and int(entity.berries_available) > 0: affordances.append("gather")
			if entity.type == "water": affordances.append("drink")
			entities.append({"type": entity.type, "id": entity.id, "name": entity.name, "distance": distance, "affordances": affordances})
			if entity.type == "berry_bush" or entity.type == "water":
				if observer.remember_location(entity):
					observer.remember({"type": "discovery", "target_id": entity.id, "description": "I found a %s." % entity.type.replace("_", " "), "importance": 7 if observer.hunger > 70 or observer.thirst > 70 else 3})
					observer._important_event = true
	return {"id": observer.agent_id, "name": observer.agent_name, "hunger": observer.hunger, "thirst": observer.thirst, "energy": observer.energy, "inventory": observer.inventory, "known_locations": observer.known_locations.values(), "personality": observer.personality, "current_goal": observer.current_goal, "position": {"x": observer.global_position.x, "y": observer.global_position.y}, "visible_entities": entities, "relationships": observer.relationships, "recent_events": observer.recent_events.slice(-8), "relevant_memories": observer.relevant_memories(visible_ids), "conversation_threads": thread_context(observer.agent_id, visible_ids), "pending_messages": observer.pending_messages, "available_actions": WorldAgent.ACTIONS}

func thread_context(agent_id: String, visible_ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for other_id in visible_ids:
		var key := _thread_key(agent_id, other_id)
		if conversation_threads.has(key): result[other_id] = conversation_threads[key].slice(-6)
	return result

func describe_visible_entities(observer: WorldAgent) -> String:
	var names: Array[String] = []
	for other: WorldAgent in agents.get_children():
		if other != observer and observer.global_position.distance_to(other.global_position) <= perception_radius: names.append(other.agent_name)
	for entity: Dictionary in environment_entities.values():
		if observer.global_position.distance_to(Vector2(float(entity.world_position.x), float(entity.world_position.y))) <= perception_radius: names.append(str(entity.name))
	return ", ".join(names) if not names.is_empty() else "nothing nearby"

func execute_intent(agent: WorldAgent, action: String, target_id: String, message: String, parameters: Dictionary = {}) -> void:
	match action:
		"gather": _gather(agent, target_id)
		"eat": _eat(agent, str(parameters.get("item", "berry")))
		"drink": _drink(agent, target_id)
		"give": _give(agent, target_id, parameters)
		"rest": agent.current_action = "rest"
		"explore": agent.set_wander_destination(_explore_destination(agent))
		"go_to_known": _go_to_known(agent, target_id)
		"talk":
			var target: WorldAgent = _agent_by_id(target_id)
			if target == null or target == agent:
				agent.mark_action_failed("INVALID_TARGET")
			elif agent.global_position.distance_to(target.global_position) > WorldConfig.INTERACTION_DISTANCE:
				_begin_approach(agent, action, target_id, message, parameters, target.global_position, target.agent_name)
			elif not agent.can_talk_to(target_id, message):
				log_event("%s TALK rejected: cooldown or repeated message." % agent.agent_name)
				agent.wait_safely()
			else:
				agent.set_talk_target(target, message)
				agent.remember({"type": "performed_action", "actor_id": agent.agent_id, "target_id": target_id, "description": "I said to %s: %s" % [target.agent_name, message], "importance": 4})
				_publish_message(agent, target, message)
		"wander": agent.set_wander_destination(_random_world_position(agent.global_position))
		_: agent.wait_safely()

func _begin_approach(agent: WorldAgent, action: String, target_id: String, message: String, parameters: Dictionary, destination: Vector2, target_name: String) -> void:
	log_event("%s target distance=%s" % [agent.agent_name, roundi(agent.global_position.distance_to(destination))])
	agent.begin_approach({"action": action, "target_id": target_id, "message": message, "parameters": parameters}, destination, target_name)

func arrived_at_target(agent: WorldAgent) -> void:
	var intent := agent.take_pending_intent()
	if intent.is_empty(): agent.mark_action_failed("NAVIGATION_FAILED"); return
	log_event("%s arrived at %s" % [agent.agent_name, str(intent.target_id)])
	agent.action_state = WorldAgent.ActionState.EXECUTING
	execute_intent(agent, str(intent.action), str(intent.target_id), str(intent.message), intent.parameters)

func _gather(agent: WorldAgent, target_id: String) -> void:
	var entity: Dictionary = environment_entities.get(target_id, {})
	if entity.is_empty(): agent.mark_action_failed("TARGET_MISSING"); return
	if entity.type != "berry_bush": agent.mark_action_failed("INVALID_TARGET"); return
	if int(entity.berries_available) <= 0: agent.mark_action_failed("RESOURCE_EMPTY"); return
	var distance := agent.global_position.distance_to(Vector2(entity.world_position.x, entity.world_position.y))
	if distance > WorldConfig.INTERACTION_DISTANCE: _begin_approach(agent, "gather", target_id, "", {}, Vector2(entity.world_position.x, entity.world_position.y), str(entity.name)); return
	entity.berries_available = int(entity.berries_available) - 1; environment_entities[target_id] = entity; agent.add_item("berry", 1)
	log_event("%s gathered 1 Berry (inventory %s)." % [agent.agent_name, agent.get_item_count("berry")]); agent.mark_action_completed(); publish_event({"type": "resource_gathered", "actor_id": agent.agent_id, "target_id": target_id, "item": "berry", "quantity": 1, "position": entity.world_position})

func _eat(agent: WorldAgent, item: String) -> void:
	if not agent.remove_item(item, 1): agent.mark_action_failed("OUT_OF_INVENTORY"); return
	agent.hunger = maxi(0, agent.hunger - WorldConfig.BERRY_NUTRITION); agent.mark_action_completed(); log_event("%s ate Berry. Hunger: %s" % [agent.agent_name, agent.hunger])

func _drink(agent: WorldAgent, target_id: String) -> void:
	var entity: Dictionary = environment_entities.get(target_id, {})
	if entity.is_empty(): agent.mark_action_failed("TARGET_MISSING"); return
	if entity.type != "water": agent.mark_action_failed("INVALID_TARGET"); return
	if agent.global_position.distance_to(Vector2(entity.world_position.x, entity.world_position.y)) > WorldConfig.INTERACTION_DISTANCE: _begin_approach(agent, "drink", target_id, "", {}, Vector2(entity.world_position.x, entity.world_position.y), str(entity.name)); return
	var old_thirst := agent.thirst; agent.thirst = maxi(0, agent.thirst - WorldConfig.WATER_HYDRATION); agent.mark_action_completed(); log_event("%s drank water. Thirst: %s -> %s" % [agent.agent_name, old_thirst, agent.thirst])

func _give(agent: WorldAgent, target_id: String, parameters: Dictionary) -> void:
	var target: WorldAgent = _agent_by_id(target_id); var quantity: int = int(parameters.get("quantity", 1)); var item := str(parameters.get("item", "berry"))
	if target == null or target == agent or quantity < 1: agent.mark_action_failed("INVALID_TARGET"); return
	if agent.global_position.distance_to(target.global_position) > WorldConfig.INTERACTION_DISTANCE: _begin_approach(agent, "give", target_id, "", parameters, target.global_position, target.agent_name); return
	if not agent.remove_item(item, quantity): agent.mark_action_failed("OUT_OF_INVENTORY"); return
	target.add_item(item, quantity); target.change_relationship(agent.agent_id, WorldConfig.GIVE_TRUST, WorldConfig.GIVE_AFFINITY); agent.mark_action_completed(); log_event("%s gave %s %s to %s." % [agent.agent_name, quantity, item, target.agent_name])

func _go_to_known(agent: WorldAgent, target_id: String) -> void:
	var known: Dictionary = agent.known_locations.get(target_id, {}); if known.is_empty(): agent.wait_safely(); return
	var p: Dictionary = known.last_known_position; agent.set_wander_destination(Vector2(float(p.x), float(p.y)))

func _explore_destination(agent: WorldAgent) -> Vector2:
	return _random_world_position(agent.global_position)

func _register_environment() -> void:
	for group in [$SimulationEntities/Trees, $SimulationEntities/BerryBushes, $SimulationEntities/WaterSources, $SimulationEntities/Rocks]:
		for node in group.get_children():
			var entity: Dictionary = {"id": node.name.to_lower(), "name": node.name.replace("_", " "), "type": str(node.get_meta("entity_type")), "world_position": {"x": node.global_position.x, "y": node.global_position.y}}
			if entity.type == "berry_bush": entity["berries_available"] = 5; entity["max_berries"] = 5
			environment_entities[entity.id] = entity

func _publish_message(actor: WorldAgent, target: WorldAgent, text: String) -> void:
	var event := {"type": "message", "actor_id": actor.agent_id, "actor_name": actor.agent_name, "target_agent_id": target.agent_id, "text": text, "position": {"x": actor.global_position.x, "y": actor.global_position.y}}
	publish_event(event)
	var key := _thread_key(actor.agent_id, target.agent_id)
	if not conversation_threads.has(key): conversation_threads[key] = []
	conversation_threads[key].append({"speaker_id": actor.agent_id, "target_id": target.agent_id, "text": text, "tick": world_tick})
	log_event("MESSAGE %s → %s: %s" % [actor.agent_name, target.agent_name, text])

func publish_event(event: Dictionary) -> void:
	_event_sequence += 1
	event["event_id"] = "event_%s" % _event_sequence
	event["tick"] = world_tick
	var pos: Dictionary = event.get("position", {})
	var event_position: Vector2 = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))
	log_event("WORLD EVENT %s actor=%s target=%s" % [event.type, event.actor_id, str(event.get("target_id", ""))])
	for observer: WorldAgent in agents.get_children():
		if observer.agent_id != str(event.actor_id) and observer.global_position.distance_to(event_position) <= perception_radius:
			observer.receive_social_event(event)

func _thread_key(first: String, second: String) -> String:
	return "%s|%s" % [first, second] if first < second else "%s|%s" % [second, first]

func _agent_by_id(id: String) -> WorldAgent:
	for agent: WorldAgent in agents.get_children():
		if agent.agent_id == id: return agent
	return null

func _random_world_position(origin: Vector2) -> Vector2:
	return Vector2(clampf(origin.x + randf_range(-220, 220), WorldConfig.MAP_BOUNDS.position.x, WorldConfig.MAP_BOUNDS.end.x), clampf(origin.y + randf_range(-180, 180), WorldConfig.MAP_BOUNDS.position.y, WorldConfig.MAP_BOUNDS.end.y))

func show_agent_info(agent: WorldAgent) -> void:
	if agent == null: return
	var relationships_text := JSON.stringify(agent.relationships)
	var memory_lines: Array[String] = []
	for memory: Dictionary in agent.memories.slice(-5): memory_lines.append("• %s" % memory.description)
	var pending_lines: Array[String] = []
	for message: Dictionary in agent.pending_messages: pending_lines.append("%s: %s" % [message.speaker_id, message.text])
	agent_panel.text = "%s\nGoal: %s | Action: %s\nHunger: %s Energy: %s\n\nRelationships: %s\n\nMemories:\n%s\n\nPending messages:\n%s\n\nReason: %s" % [agent.agent_name.to_upper(), agent.current_goal, agent.current_action, agent.hunger, agent.energy, relationships_text, "\n".join(memory_lines) if not memory_lines.is_empty() else "None", "\n".join(pending_lines) if not pending_lines.is_empty() else "None", agent.last_reason]

func log_event(text: String) -> void:
	var stamp := Time.get_time_string_from_system()
	event_panel.text += "[%s] %s\n" % [stamp, text]
	event_panel.scroll_vertical = event_panel.get_line_count()
	if _text_log:
		_text_log.store_line("[%s] %s" % [stamp, text])
		_text_log.flush()
	if _jsonl_log:
		_jsonl_log.store_line(JSON.stringify({"timestamp": stamp, "tick": world_tick, "message": text}))
		_jsonl_log.flush()
