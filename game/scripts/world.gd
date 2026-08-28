extends Node2D

@export var server_url := "http://127.0.0.1:8000"
@export var perception_radius := 650.0
@export var take_distance := 55.0
var apple_available := true
@onready var apple: Node2D = $Apple
@onready var agents: Node2D = $Agents
@onready var event_panel: TextEdit = $EventPanel

func _ready() -> void:
	randomize()
	for agent in agents.get_children():
		agent.setup(self, server_url)
	log_event("World ready. Apple is available.")

func build_observation(observer: WorldAgent) -> Dictionary:
	var entities: Array[Dictionary] = []
	for other in agents.get_children():
		if other != observer and observer.global_position.distance_to(other.global_position) <= perception_radius:
			entities.append({"type": "agent", "id": other.agent_id, "name": other.agent_name})
	if apple_available and observer.global_position.distance_to(apple.global_position) <= perception_radius:
		entities.append({"type": "food", "id": "apple_1", "name": "Apple"})
	return {"id": observer.agent_id, "name": observer.agent_name, "hunger": observer.hunger, "energy": observer.energy, "personality": Array(observer.personality), "position": {"x": observer.global_position.x, "y": observer.global_position.y}, "visible_entities": entities, "available_actions": WorldAgent.ACTIONS}

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
			if target:
				agent.set_talk_target(target, message)
				log_event("%s: %s" % [agent.agent_name, message if not message.is_empty() else "Hello!"])
			else:
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
