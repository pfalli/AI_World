extends Node2D

@export var server_url := "http://127.0.0.1:8000"
@export var perception_radius := 650.0
@export var take_distance := 55.0
var apple_available := true
var world_tick := 0
var selected_agent: WorldAgent
@onready var apple: Node2D = $Apple
@onready var agents: Node2D = $Agents
@onready var event_panel: TextEdit = $EventPanel
@onready var agent_panel: TextEdit = $AgentPanel

func _ready() -> void:
	randomize()
	for agent in agents.get_children():
		agent.setup(self, server_url)
		if selected_agent == null: selected_agent = agent
	log_event("World ready. Apple is available.")
	show_agent_info(selected_agent)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for agent in agents.get_children():
			if agent.global_position.distance_to(get_global_mouse_position()) < 36.0:
				selected_agent = agent
				show_agent_info(agent)
				get_viewport().set_input_as_handled()
				return

func build_observation(observer: WorldAgent) -> Dictionary:
	# A logical tick advances only when a decision context is assembled, not every frame.
	world_tick += 1
	var entities: Array[Dictionary] = []
	for other in agents.get_children():
		if other != observer and observer.global_position.distance_to(other.global_position) <= perception_radius:
			entities.append({"type": "agent", "id": other.agent_id, "name": other.agent_name})
	if apple_available and observer.global_position.distance_to(apple.global_position) <= perception_radius:
		entities.append({"type": "food", "id": "apple_1", "name": "Apple"})
	var visible_ids: Array = []
	for entity in entities:
		if entity.type == "agent": visible_ids.append(entity.id)
	var events: Array[String] = []
	for event in observer.recent_events.slice(-8): events.append(str(event.get("description", "event")))
	return {"id": observer.agent_id, "name": observer.agent_name, "hunger": observer.hunger, "energy": observer.energy, "personality": observer.personality, "current_goal": observer.current_goal, "position": {"x": observer.global_position.x, "y": observer.global_position.y}, "visible_entities": entities, "relationships": observer.relationships, "recent_events": events, "relevant_memories": observer.relevant_memories(visible_ids), "recent_messages": observer.recent_messages.slice(-8), "available_actions": WorldAgent.ACTIONS}

func describe_visible_entities(observer: WorldAgent) -> String:
	var names: Array[String] = []
	var observation := build_observation(observer)
	for entity in observation.get("visible_entities", []):
		names.append(str(entity.get("name", "unknown")))
	return ", ".join(names) if not names.is_empty() else "nothing nearby"

func execute_intent(agent: WorldAgent, action: String, target_id: String, message: String) -> void:
	match action:
		"take_apple": _take_apple(agent, target_id)
		"talk":
			var target := _agent_by_id(target_id)
			if target and agent.can_send_message(target_id, message):
				agent.set_talk_target(target, message)
				agent.remember("action", "I told %s: %s" % [target.agent_name, message], 4, [target_id])
				var message_event := {"type": "message", "actor_id": agent.agent_id, "actor_name": agent.agent_name, "target_agent_id": target_id, "message": message, "description": "%s said to %s: %s" % [agent.agent_name, target.agent_name, message], "position": {"x": agent.global_position.x, "y": agent.global_position.y}}
				publish_event(message_event)
				log_event("%s → %s: %s" % [agent.agent_name, target.agent_name, message])
			else:
				log_event("%s talk prevented (invalid or repeated message)." % agent.agent_name)
				agent.wait_safely()
		"wander": agent.set_wander_destination(_random_world_position(agent.global_position))
		_: agent.wait_safely()

func _take_apple(agent: WorldAgent, target_id: String) -> void:
	if target_id != "apple_1" or not apple_available:
		log_event("%s could not take Apple (unavailable)." % agent.agent_name)
		agent.wait_safely()
		return
	if agent.global_position.distance_to(apple.global_position) > take_distance:
		log_event("%s could not take Apple (too far)." % agent.agent_name)
		agent.wait_safely()
		return
	apple_available = false
	apple.hide()
	agent.eat_apple()
	log_event("%s took Apple." % agent.agent_name)
	agent.remember("action", "I took the only apple because I was hungry.", 6, [])
	publish_event({"type": "resource_taken", "actor_id": agent.agent_id, "actor_name": agent.agent_name, "target_id": "apple_1", "description": "%s took Apple." % agent.agent_name, "position": {"x": apple.global_position.x, "y": apple.global_position.y}})

func publish_event(event: Dictionary) -> void:
	var event_position := Vector2(float(event.position.x), float(event.position.y))
	for observer in agents.get_children():
		if observer.agent_id != str(event.get("actor_id", "")) and observer.global_position.distance_to(event_position) <= perception_radius:
			observer.receive_social_event(event)

func show_agent_info(agent: WorldAgent) -> void:
	if agent == null: return
	var relationship_lines: Array[String] = []
	for other_id in agent.relationships:
		var relation: Dictionary = agent.relationships[other_id]
		relationship_lines.append("%s: trust %s, affinity %s" % [other_id, relation.trust, relation.affinity])
	var memory_lines: Array[String] = []
	for memory in agent.memories.slice(-5): memory_lines.append("• %s" % memory.description)
	var message_lines: Array[String] = []
	for message in agent.recent_messages.slice(-5): message_lines.append("%s: %s" % [message.from_name, message.message])
	agent_panel.text = "%s\n\nGoal: %s\nAction: %s\nHunger: %s\nEnergy: %s\n\nPersonality:\n%s\n\nRelationships:\n%s\n\nRecent memories:\n%s\n\nRecent messages:\n%s\n\nLast AI reason:\n%s" % [agent.agent_name.to_upper(), agent.current_goal, agent.current_action, agent.hunger, agent.energy, JSON.stringify(agent.personality), "\n".join(relationship_lines) if not relationship_lines.is_empty() else "Neutral", "\n".join(memory_lines) if not memory_lines.is_empty() else "None", "\n".join(message_lines) if not message_lines.is_empty() else "None", agent.last_reason]

func _agent_by_id(id: String) -> WorldAgent:
	for agent in agents.get_children():
		if agent.agent_id == id:
			return agent
	return null

func _random_world_position(origin: Vector2) -> Vector2:
	return Vector2(clamp(origin.x + randf_range(-140, 140), 60.0, 900.0), clamp(origin.y + randf_range(-100, 100), 100.0, 420.0))

func log_event(text: String) -> void:
	var stamp := Time.get_time_string_from_system()
	event_panel.text += "[%s] %s\n" % [stamp, text]
	event_panel.scroll_vertical = event_panel.get_line_count()
