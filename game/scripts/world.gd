extends Node2D

@export var server_url := "http://127.0.0.1:8000"
@export var perception_radius := WorldConfig.PERCEPTION_RADIUS
var environment_entities: Dictionary = {}
var world_tick := 0
var _tick_seconds := 0.0
var _event_sequence := 0
var conversation_threads: Dictionary = {}
var selected_agent: WorldAgent
var _text_log: FileAccess
var _jsonl_log: FileAccess
@onready var agents: Node2D = $Agents
@onready var event_panel: TextEdit = $EventPanel
@onready var agent_panel: TextEdit = $AgentPanel

func _ready() -> void:
	randomize()
	_open_simulation_logs()
	_register_environment()
	for agent: WorldAgent in agents.get_children():
		agent.setup(self, server_url)
		if selected_agent == null: selected_agent = agent
	log_event("World ready. Forest resources are available.")
	show_agent_info(selected_agent)

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for agent: WorldAgent in agents.get_children():
			if agent.global_position.distance_to(get_global_mouse_position()) < 36.0:
				selected_agent = agent
				show_agent_info(agent)
				get_viewport().set_input_as_handled()
				return

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
			if target == null or target == agent or agent.global_position.distance_to(target.global_position) > perception_radius:
				log_event("%s TALK rejected: invalid, self, or unreachable target." % agent.agent_name)
				agent.wait_safely()
			elif not agent.can_talk_to(target_id, message):
				log_event("%s TALK rejected: cooldown or repeated message." % agent.agent_name)
				agent.wait_safely()
			else:
				agent.set_talk_target(target, message)
				agent.remember({"type": "performed_action", "actor_id": agent.agent_id, "target_id": target_id, "description": "I said to %s: %s" % [target.agent_name, message], "importance": 4})
				_publish_message(agent, target, message)
		"wander": agent.set_wander_destination(_random_world_position(agent.global_position))
		_: agent.wait_safely()

func _gather(agent: WorldAgent, target_id: String) -> void:
	var entity: Dictionary = environment_entities.get(target_id, {})
	if entity.is_empty() or entity.type != "berry_bush" or int(entity.berries_available) <= 0 or agent.global_position.distance_to(Vector2(entity.world_position.x, entity.world_position.y)) > WorldConfig.INTERACTION_DISTANCE:
		log_event("%s gather failed: unavailable or too far." % agent.agent_name); agent.wait_safely(); return
	entity.berries_available = int(entity.berries_available) - 1; environment_entities[target_id] = entity; agent.add_item("berry", 1)
	log_event("%s gathered 1 Berry (inventory %s)." % [agent.agent_name, agent.get_item_count("berry")]); publish_event({"type": "resource_gathered", "actor_id": agent.agent_id, "target_id": target_id, "item": "berry", "quantity": 1, "position": entity.world_position})

func _eat(agent: WorldAgent, item: String) -> void:
	if not agent.remove_item(item, 1): log_event("%s eat failed: no %s." % [agent.agent_name, item]); agent.wait_safely(); return
	agent.hunger = maxi(0, agent.hunger - WorldConfig.BERRY_NUTRITION); agent.wait_safely(); log_event("%s ate Berry. Hunger: %s" % [agent.agent_name, agent.hunger])

func _drink(agent: WorldAgent, target_id: String) -> void:
	var entity: Dictionary = environment_entities.get(target_id, {})
	if entity.is_empty() or entity.type != "water" or agent.global_position.distance_to(Vector2(entity.world_position.x, entity.world_position.y)) > WorldConfig.INTERACTION_DISTANCE: log_event("%s drink failed." % agent.agent_name); agent.wait_safely(); return
	agent.thirst = maxi(0, agent.thirst - WorldConfig.WATER_HYDRATION); agent.wait_safely(); log_event("%s drank water. Thirst: %s" % [agent.agent_name, agent.thirst])

func _give(agent: WorldAgent, target_id: String, parameters: Dictionary) -> void:
	var target := _agent_by_id(target_id); var quantity := int(parameters.get("quantity", 1))
	if target == null or target == agent or quantity < 1 or not agent.remove_item(str(parameters.get("item", "berry")), quantity): log_event("%s give failed." % agent.agent_name); agent.wait_safely(); return
	target.add_item("berry", quantity); target.change_relationship(agent.agent_id, WorldConfig.GIVE_TRUST, WorldConfig.GIVE_AFFINITY); log_event("%s gave %s berry to %s." % [agent.agent_name, quantity, target.agent_name])

func _go_to_known(agent: WorldAgent, target_id: String) -> void:
	var known: Dictionary = agent.known_locations.get(target_id, {}); if known.is_empty(): agent.wait_safely(); return
	var p: Dictionary = known.last_known_position; agent.set_wander_destination(Vector2(float(p.x), float(p.y)))

func _explore_destination(agent: WorldAgent) -> Vector2:
	return _random_world_position(agent.global_position)

func _register_environment() -> void:
	for node in $Environment.get_children():
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
