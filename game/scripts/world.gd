extends Node2D

var server_url := ""
@export var perception_radius := WorldConfig.PERCEPTION_RADIUS
var environment_entities: Dictionary = {}
var world_tick := 0
var _tick_seconds := 0.0
var _event_sequence := 0
var conversation_threads: Dictionary = {}
var conversation_sessions: Dictionary = {}
var selected_agent: WorldAgent
var _text_log: FileAccess
var _jsonl_log: FileAccess
@onready var agents: Node2D = $SimulationEntities/Agents
@onready var event_panel: TextEdit = $HUD/EventPanel
@onready var agent_panel: TextEdit = $HUD/AgentPanel
@onready var agent_panel_close: Button = $HUD/AgentPanelClose
@onready var ground: TileMapLayer = $VisualWorld/Ground
@onready var terrain: TileMapLayer = $VisualWorld/Terrain
@onready var decorations: Node2D = $VisualWorld/Decorations
var debug_visible := false
const GRASS_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/grass.png")
const WATER_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/grass_deep_water.png")
const TREE_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/trees.png")
const BUSH_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/bushes.png")
const STONE_TEXTURE := preload("res://assets/seasons_of_forest_free_v1/texture only/Forest Tileset - Free/stones.png")
const API_CONFIG := preload("res://scripts/api_config.gd")
const INTENT_PLANNER := preload("res://scripts/intent_planner.gd")
const ACTION_VALIDATOR := preload("res://scripts/action_validator.gd")
const CONVERSATION_SESSION := preload("res://scripts/conversation_session.gd")

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
	event_panel.visible = true
	agent_panel.visible = false
	agent_panel_close.visible = false
	agent_panel_close.pressed.connect(_close_agent_panel)

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
		_regrow_resources()
		_expire_conversations()
	if selected_agent: show_agent_info(selected_agent)
	_update_selection_indicator()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			debug_visible = not debug_visible
			for agent: WorldAgent in agents.get_children(): agent.set_debug_visible(debug_visible)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for agent: WorldAgent in agents.get_children():
			if agent.global_position.distance_to(get_global_mouse_position()) < 36.0:
				selected_agent = agent
				agent_panel.visible = true
				agent_panel_close.visible = true
				show_agent_info(agent)
				get_viewport().set_input_as_handled()
				return

func _close_agent_panel() -> void:
	selected_agent = null
	agent_panel.visible = false
	agent_panel_close.visible = false

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
			entities.append({"type": "agent", "id": other.agent_id, "name": other.agent_name, "distance": observer.global_position.distance_to(other.global_position)})
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
	return {"id": observer.agent_id, "name": observer.agent_name, "hunger": observer.hunger, "thirst": observer.thirst, "energy": observer.energy, "social_need": observer.social_need, "safety": observer.safety, "curiosity_drive": observer.curiosity_drive, "inventory": observer.inventory, "known_locations": observer.known_locations.values(), "personality": observer.personality, "current_goal": observer.current_goal, "position": {"x": observer.global_position.x, "y": observer.global_position.y}, "visible_entities": entities, "relationships": observer.relationships, "recent_events": observer.recent_events.slice(-8), "relevant_memories": observer.relevant_memories(visible_ids), "conversation_threads": thread_context(observer.agent_id, visible_ids), "pending_messages": observer.pending_messages, "decision_guidance": _decision_guidance(observer), "available_intents": _available_intents(observer)}

func _available_intents(observer: WorldAgent) -> Array[String]:
	var intents: Array[String] = []
	for intent in WorldAgent.INTENTS:
		intents.append(str(intent))
	if observer.hunger < WorldConfig.FOOD_SEARCH_THRESHOLD or not observer.has_item("berry"):
		intents.erase("consume_item")
	if not observer.has_item("berry"):
		intents.erase("give_item")
	if observer.hunger < WorldConfig.FOOD_SEARCH_THRESHOLD:
		intents.erase("gather_resource")
	if observer.hunger >= WorldConfig.FOOD_SEARCH_THRESHOLD and not _has_actionable_resource(observer, "berry_bush"):
		intents.erase("gather_resource")
	if observer.thirst < WorldConfig.WATER_SEARCH_THRESHOLD or not _has_actionable_resource(observer, "water"):
		intents.erase("drink_water")
	return intents

func available_intents_for(observer: WorldAgent) -> Array[String]:
	return _available_intents(observer)

func _has_actionable_resource(observer: WorldAgent, resource_type: String) -> bool:
	for entity: Dictionary in environment_entities.values():
		if str(entity.get("type", "")) != resource_type: continue
		if resource_type == "berry_bush" and int(entity.get("berries_available", 0)) <= 0: continue
		var is_visible := observer.global_position.distance_to(Vector2(float(entity.world_position.x), float(entity.world_position.y))) <= perception_radius
		if is_visible or observer.known_locations.has(str(entity.id)): return true
	return false

func _decision_guidance(observer: WorldAgent) -> Array[String]:
	var guidance: Array[String] = []
	if observer.hunger < WorldConfig.FOOD_SEARCH_THRESHOLD and observer.thirst < WorldConfig.WATER_SEARCH_THRESHOLD:
		guidance.append("Food and water are not needed yet. Prefer a short conversation with a visible person, exploration, rest, or waiting.")
	elif observer.hunger < WorldConfig.FOOD_SEARCH_THRESHOLD:
		guidance.append("Food is not needed yet. Do not gather or consume food; focus on water only if thirst needs it.")
	elif observer.thirst < WorldConfig.WATER_SEARCH_THRESHOLD:
		guidance.append("Water is not needed yet. Do not seek or drink water; focus on food only if hunger needs it.")
	if observer.thirst <= 25:
		guidance.append("Your thirst is already satisfied; drinking water again has no useful effect right now.")
	if observer.hunger >= 70 and observer.has_item("berry"):
		guidance.append("You are carrying berries while hungry; consuming one directly reduces hunger.")
	if observer.hunger >= 85 or observer.thirst >= 85:
		guidance.append("A survival need is critical. Consider food or water before optional exploration or conversation.")
	for other_id in conversation_threads.keys():
		var thread: Array = conversation_threads[other_id]
		if not thread.is_empty() and str(thread.back().get("speaker_id", "")) == observer.agent_id:
			guidance.append("Your latest message to %s is unanswered; do not send another initiating message yet." % str(thread.back().get("target_id", "that agent")))
	return guidance.slice(0, 6)

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

func accept_intent(agent: WorldAgent, intent: Dictionary) -> void:
	var intent_name := str(intent.get("intent", "wait"))
	var planner := INTENT_PLANNER.new()
	var plan := planner.plan(intent)
	log_event("[NEED] %s hunger=%s thirst=%s energy=%s social=%s safety=%s curiosity=%s" % [agent.agent_name, agent.hunger, agent.thirst, agent.energy, agent.social_need, agent.safety, agent.curiosity_drive])
	log_event("[INTENT] %s: %s%s" % [agent.agent_name, intent_name, " -> %s" % str(intent.get("target_id", "")) if not str(intent.get("target_id", "")).is_empty() else ""])
	log_event("[PLAN] %s" % planner.describe(plan))
	agent.start_action(intent_name)
	agent.set_primitive_plan(plan)
	_execute_next_primitive(agent)

func _execute_next_primitive(agent: WorldAgent) -> void:
	var primitive := agent.take_next_primitive()
	if primitive.is_empty():
		log_event("[RESULT] %s completed plan" % agent.agent_name)
		agent.mark_action_completed()
		return
	log_event("[ACTION] %s %s" % [str(primitive.type), str(primitive.get("target_id", ""))])
	var validation := ACTION_VALIDATOR.validate(primitive, _primitive_context(agent, primitive))
	if not bool(validation.valid):
		_reject_primitive(agent, primitive, str(validation.reason))
		return
	log_event("[VALIDATION] valid")
	_execute_valid_primitive(agent, primitive)

func _primitive_context(agent: WorldAgent, primitive: Dictionary) -> Dictionary:
	var target_id := str(primitive.get("target_id", ""))
	var target: Dictionary = {}
	if environment_entities.has(target_id): target = environment_entities[target_id]
	else:
		var other := _agent_by_id(target_id)
		if other != null: target = {"id": other.agent_id, "name": other.agent_name, "type": "agent", "world_position": {"x": other.global_position.x, "y": other.global_position.y}}
	var target_position := Vector2(float(target.get("world_position", {}).get("x", agent.global_position.x)), float(target.get("world_position", {}).get("y", agent.global_position.y)))
	return {"target": target, "distance": agent.global_position.distance_to(target_position), "interaction_distance": WorldConfig.INTERACTION_DISTANCE, "inventory": agent.inventory}

func _execute_valid_primitive(agent: WorldAgent, primitive: Dictionary) -> void:
	var type := str(primitive.type)
	var target_id := str(primitive.get("target_id", ""))
	var parameters: Dictionary = primitive.get("parameters", {})
	if type == "MOVE_TO":
		var destination := _explore_destination(agent) if target_id == "exploration" else _target_position(target_id)
		var target_name := "exploration" if target_id == "exploration" else _target_name(target_id)
		agent.begin_approach(primitive, destination, target_name)
		return
	if type == "PICK_UP":
		var entity: Dictionary = environment_entities[target_id]
		entity.berries_available = int(entity.berries_available) - 1
		environment_entities[target_id] = entity
		agent.add_item(str(parameters.get("item", "berry")), 1)
		log_event("[RESULT] %s picked up Berry" % agent.agent_name)
		publish_event({"type": "resource_gathered", "actor_id": agent.agent_id, "actor_name": agent.agent_name, "target_id": target_id, "item": str(parameters.get("item", "berry")), "quantity": 1, "position": entity.world_position})
	elif type == "USE":
		var old_thirst := agent.thirst
		agent.thirst = maxi(0, agent.thirst - WorldConfig.WATER_HYDRATION)
		log_event("[RESULT] %s drank water: %s -> %s" % [agent.agent_name, old_thirst, agent.thirst])
	elif type == "CONSUME":
		var item := str(parameters.get("item", "berry"))
		agent.remove_item(item, 1)
		agent.hunger = maxi(0, agent.hunger - WorldConfig.BERRY_NUTRITION)
		log_event("[RESULT] %s consumed %s" % [agent.agent_name, item])
	elif type == "SPEAK":
		var target := _agent_by_id(target_id)
		var message := str(parameters.get("message", ""))
		if target == null:
			_reject_primitive(agent, primitive, "recipient no longer exists")
			return
		if not _conversation_available(agent, target) or not agent.can_talk_to(target_id, message):
			log_event("[VALIDATION] SPEAK %s deferred: conversation is unavailable" % target_id)
			agent.defer_decision("Conversation with %s is temporarily unavailable." % target.agent_name)
			return
		agent.remember({"type": "performed_action", "actor_id": agent.agent_id, "target_id": target_id, "description": "I said to %s: %s" % [target.agent_name, message], "importance": 4})
		_publish_message(agent, target, message)
		log_event("[RESULT] %s spoke to %s" % [agent.agent_name, target.agent_name])
	elif type == "DROP":
		var recipient := _agent_by_id(target_id)
		var quantity := int(parameters.get("quantity", 1))
		var dropped_item := str(parameters.get("item", "berry"))
		agent.remove_item(dropped_item, quantity)
		recipient.add_item(dropped_item, quantity)
		agent.remember({"type": "gave_item", "actor_id": agent.agent_id, "target_id": recipient.agent_id, "description": "I gave %s %s to %s." % [quantity, dropped_item, recipient.agent_name], "importance": 6})
		publish_event({"type": "gift", "actor_id": agent.agent_id, "actor_name": agent.agent_name, "target_agent_id": recipient.agent_id, "target_id": recipient.agent_id, "item": dropped_item, "quantity": quantity, "position": {"x": agent.global_position.x, "y": agent.global_position.y}})
		log_event("[RESULT] %s gave %s %s to %s" % [agent.agent_name, quantity, dropped_item, recipient.agent_name])
	elif type == "WAIT":
		if str(parameters.get("purpose", "")) == "rest":
			agent.current_action = "rest"
			log_event("[RESULT] %s is resting" % agent.agent_name)
			return
		agent.defer_decision("Waiting until the next decision interval.")
		log_event("[RESULT] %s waits until the next decision interval" % agent.agent_name)
		return
	_execute_next_primitive(agent)

func _reject_primitive(agent: WorldAgent, primitive: Dictionary, reason: String) -> void:
	var description := ACTION_VALIDATOR.failure_observation(primitive, reason)
	log_event("[VALIDATION] %s %s rejected: %s" % [str(primitive.type), str(primitive.get("target_id", "")), reason])
	log_event("[OBSERVATION] %s learned: %s" % [agent.agent_name, description])
	if reason == "resource is empty":
		agent.forget_location(str(primitive.get("target_id", "")))
		agent.remember({"type": "resource_empty", "target_id": str(primitive.get("target_id", "")), "description": description, "importance": 5})
		agent.defer_decision("The resource is empty; waiting for new information.")
		return
	agent.observe_action_failure(description)

func _target_position(target_id: String) -> Vector2:
	if environment_entities.has(target_id):
		var position: Dictionary = environment_entities[target_id].world_position
		return Vector2(float(position.x), float(position.y))
	var target := _agent_by_id(target_id)
	return target.global_position if target != null else Vector2.ZERO

func _target_name(target_id: String) -> String:
	if environment_entities.has(target_id): return str(environment_entities[target_id].name)
	var target := _agent_by_id(target_id)
	return target.agent_name if target != null else target_id

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
	var primitive := agent.take_pending_intent()
	if primitive.is_empty(): agent.mark_action_failed("NAVIGATION_FAILED"); return
	log_event("[RESULT] %s reached %s" % [agent.agent_name, str(primitive.get("target_id", ""))])
	agent.action_state = WorldAgent.ActionState.EXECUTING
	_execute_next_primitive(agent)

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
			if entity.type == "berry_bush":
				entity["berries_available"] = 5
				entity["max_berries"] = 5
				entity["last_regrow_tick"] = world_tick
			environment_entities[entity.id] = entity

func _regrow_resources() -> void:
	for entity_id in environment_entities.keys():
		var entity: Dictionary = environment_entities[entity_id]
		if str(entity.get("type", "")) != "berry_bush": continue
		if int(entity.get("berries_available", 0)) >= int(entity.get("max_berries", 0)): continue
		if world_tick - int(entity.get("last_regrow_tick", world_tick)) < WorldConfig.BERRY_REGROW_TICKS: continue
		entity["berries_available"] = int(entity.berries_available) + 1
		entity["last_regrow_tick"] = world_tick
		environment_entities[entity_id] = entity
		log_event("[RESOURCE] %s regrew a berry (%s/%s)" % [str(entity.name), entity.berries_available, entity.max_berries])

func _publish_message(actor: WorldAgent, target: WorldAgent, text: String) -> void:
	var key := _thread_key(actor.agent_id, target.agent_id)
	var previous_session: Dictionary = conversation_sessions.get(key, {})
	var is_closing_reply := bool(previous_session.get("ended", false)) and actor.has_pending_from(target.agent_id)
	# The one reply admitted after the turn cap closes the exchange.  It remains
	# a visible social event and memory, but does not create another mandatory
	# response that would bypass the cap indefinitely.
	var event := {"type": "message", "actor_id": actor.agent_id, "actor_name": actor.agent_name, "target_agent_id": target.agent_id, "text": text, "expects_reply": not is_closing_reply, "position": {"x": actor.global_position.x, "y": actor.global_position.y}}
	publish_event(event)
	if not conversation_threads.has(key): conversation_threads[key] = []
	conversation_threads[key].append({"speaker_id": actor.agent_id, "target_id": target.agent_id, "text": text, "tick": world_tick})
	var session: Dictionary = conversation_sessions.get(key, CONVERSATION_SESSION.start(actor.agent_id, target.agent_id, world_tick))
	session = CONVERSATION_SESSION.record(session, actor.agent_id, world_tick, WorldConfig.CONVERSATION_MAX_TURNS)
	conversation_sessions[key] = session
	# This is the reply point: do not discard a received message merely because
	# the agent had to move before speaking.
	actor.resolve_pending_from(target.agent_id)
	actor.complete_social_interaction(target.agent_id, "spoke")
	actor.show_conversation(text)
	log_event("[SOCIAL] %s → %s: %s" % [actor.agent_name, target.agent_name, text])
	if bool(session.ended):
		session.ended_tick = world_tick
		conversation_sessions[key] = session
		log_event("[SOCIAL] conversation %s ended after %s turns" % [key, session.turn_count])

func _conversation_available(actor: WorldAgent, target: WorldAgent) -> bool:
	var key := _thread_key(actor.agent_id, target.agent_id)
	var session: Dictionary = conversation_sessions.get(key, {})
	# A newly received direct message gets one prompt reply even if the preceding
	# exchange just reached its turn cap or inactivity boundary.  Without this,
	# the final speaker in a conversation is systematically left unanswered.
	if actor.has_pending_from(target.agent_id):
		return true
	if session.is_empty():
		return actor.can_initiate_socially()
	if bool(session.get("ended", false)):
		# A completed session cannot instantly restart, but may become a new conversation
		# after a meaningful pause rather than permanently silencing that pair.
		if world_tick - int(session.get("ended_tick", world_tick)) >= WorldConfig.CONVERSATION_INACTIVITY_TICKS:
			conversation_sessions.erase(key)
			return actor.can_initiate_socially()
		return false
	if not CONVERSATION_SESSION.is_available(session, world_tick, WorldConfig.CONVERSATION_MAX_TURNS, WorldConfig.CONVERSATION_INACTIVITY_TICKS):
		return false
	return actor.can_initiate_socially()

func _expire_conversations() -> void:
	for key in conversation_sessions.keys():
		var session: Dictionary = conversation_sessions[key]
		if not bool(session.get("ended", false)) and world_tick - int(session.get("last_tick", world_tick)) >= WorldConfig.CONVERSATION_INACTIVITY_TICKS:
			session.ended = true
			session.ended_tick = world_tick
			conversation_sessions[key] = session
			log_event("[SOCIAL] conversation %s ended due to inactivity" % key)

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

func live_agent_target(id: String) -> Dictionary:
	var target := _agent_by_id(id)
	if target == null: return {"found": false}
	return {"found": true, "position": target.global_position}

func _random_world_position(origin: Vector2) -> Vector2:
	return Vector2(clampf(origin.x + randf_range(-220, 220), WorldConfig.MAP_BOUNDS.position.x, WorldConfig.MAP_BOUNDS.end.x), clampf(origin.y + randf_range(-180, 180), WorldConfig.MAP_BOUNDS.position.y, WorldConfig.MAP_BOUNDS.end.y))

func show_agent_info(agent: WorldAgent) -> void:
	if agent == null: return
	var relationships_text := JSON.stringify(agent.relationships)
	var memory_lines: Array[String] = []
	for memory: Dictionary in agent.memories.slice(-5): memory_lines.append("• %s" % memory.description)
	var pending_lines: Array[String] = []
	for message: Dictionary in agent.pending_messages: pending_lines.append("%s: %s" % [message.speaker_id, message.text])
	agent_panel.text = "%s\nGoal: %s | Action: %s\nHunger: %s Thirst: %s Energy: %s Social: %s Safety: %s Curiosity: %s\n\nRelationships: %s\n\nMemories:\n%s\n\nPending messages:\n%s\n\nReason: %s" % [agent.agent_name.to_upper(), agent.current_goal, agent.current_action, agent.hunger, agent.thirst, agent.energy, agent.social_need, agent.safety, agent.curiosity_drive, relationships_text, "\n".join(memory_lines) if not memory_lines.is_empty() else "None", "\n".join(pending_lines) if not pending_lines.is_empty() else "None", agent.last_reason]

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
