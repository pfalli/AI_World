class_name WorldAgent
extends CharacterBody2D

@export var agent_id := "agent"
@export var agent_name := "Agent"
@export var hunger := 80
@export var energy := 100
@export var personality: Dictionary = {"friendliness": 0.5, "cooperation": 0.5, "curiosity": 0.5, "selfishness": 0.5, "aggression": 0.5}
@export var body_color := Color.WHITE
@export var decision_interval := 5.0
@export var max_memories := 100

const ACTIONS := ["take_apple", "talk", "wander", "wait"]
const GOALS := ["find_food", "socialize", "explore", "rest", "idle"]
const SPEED := 115.0
const CONTEXT_LIMIT := 8
var current_action := "wait"
var current_goal := "idle"
var relationships: Dictionary = {}
var memories: Array[Dictionary] = []
var recent_events: Array[Dictionary] = []
var recent_messages: Array[Dictionary] = []
var last_reason := ""
var _last_messages: Dictionary = {}
var _destination := Vector2.ZERO
var _client: AIClient
var _world: Node

func setup(world: Node, server_address: String) -> void:
	_world = world
	_client = AIClient.new()
	_client.server_url = server_address
	add_child(_client)
	_client.decision_received.connect(_on_decision_received)
	_client.request_failed.connect(_on_request_failed)
	$Body.color = body_color
	update_status("Waiting")
	await get_tree().create_timer(decision_interval + randf_range(0.2, 1.2)).timeout
	_decision_loop()

func _physics_process(_delta: float) -> void:
	if current_action == "wander" or current_action == "talk":
		velocity = global_position.direction_to(_destination) * SPEED
		if global_position.distance_to(_destination) < 5.0:
			velocity = Vector2.ZERO
		move_and_slide()

func _decision_loop() -> void:
	while is_instance_valid(_world):
		_world.log_event("%s observes %s" % [agent_name, _world.describe_visible_entities(self)])
		_client.request_decision(_world.build_observation(self))
		await get_tree().create_timer(decision_interval).timeout

func _on_decision_received(decision: Dictionary) -> void:
	var action := str(decision.get("action", "wait"))
	current_goal = str(decision.get("goal", "idle"))
	if not ACTIONS.has(action): action = "wait"
	if not GOALS.has(current_goal): current_goal = "idle"
	last_reason = str(decision.get("reason", "No reason provided."))
	_world.log_event("%s decided %s (%s)." % [agent_name, action.to_upper(), current_goal])
	_world.execute_intent(self, action, str(decision.get("target_id", "")), str(decision.get("message", "")))
	_world.show_agent_info(self)

func _on_request_failed(error_text: String) -> void:
	wait_safely()
	last_reason = "AI unavailable; safe fallback."
	_world.log_event("%s AI fallback: %s" % [agent_name, error_text])

func receive_social_event(event: Dictionary) -> void:
	recent_events.append(event)
	if recent_events.size() > CONTEXT_LIMIT: recent_events.pop_front()
	var event_type := str(event.get("type", "event"))
	var actor_id := str(event.get("actor_id", ""))
	if event_type == "message" and str(event.get("target_agent_id", "")) == agent_id:
		var message := {"from_id": actor_id, "from_name": str(event.get("actor_name", "Someone")), "message": str(event.get("message", ""))}
		recent_messages.append(message)
		if recent_messages.size() > CONTEXT_LIMIT: recent_messages.pop_front()
		remember("conversation", "%s told me: %s" % [message.from_name, message.message], 5, [actor_id])
		_world.log_event("%s remembered %s's message." % [agent_name, message.from_name])
	elif event_type == "resource_taken" and actor_id != agent_id:
		var actor_name := str(event.get("actor_name", "Another agent"))
		remember("event", "%s took the only apple while I was hungry." % actor_name, 8 if hunger > 50 else 5, [actor_id])
		if hunger > 50:
			change_relationship(actor_id, -15, -5)
		_world.log_event("%s observed: %s" % [agent_name, event.get("description", "A resource was taken.")])

func remember(memory_type: String, description: String, importance: int, related_agents: Array) -> void:
	memories.append({"id": "%s_%s" % [agent_id, _world.world_tick], "timestamp": Time.get_time_string_from_system(), "type": memory_type, "description": description, "importance": clampi(importance, 1, 10), "related_agents": related_agents, "created_at_tick": _world.world_tick})
	if memories.size() > max_memories:
		memories.sort_custom(func(a, b): return a.importance < b.importance or (a.importance == b.importance and a.created_at_tick < b.created_at_tick))
		memories.pop_front()
	_world.log_event("%s memory created: %s" % [agent_name, description])

func relevant_memories(visible_ids: Array) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for memory in memories:
		var relevance := 0
		for related_id in memory.related_agents:
			if visible_ids.has(related_id): relevance += 4
		var age: int = maxi(0, _world.world_tick - int(memory.created_at_tick))
		memory["_score"] = int(memory.importance) * 10 + relevance - min(age, 30)
		scored.append(memory)
	scored.sort_custom(func(a, b): return a._score > b._score)
	var result: Array[Dictionary] = []
	for memory in scored.slice(0, CONTEXT_LIMIT): result.append({"description": memory.description, "importance": memory.importance})
	return result

func change_relationship(other_id: String, trust_delta: int, affinity_delta: int) -> void:
	if other_id.is_empty() or other_id == agent_id: return
	var relation: Dictionary = relationships.get(other_id, {"trust": 0, "affinity": 0})
	var old_trust := int(relation.trust)
	relation.trust = clampi(old_trust + trust_delta, -100, 100)
	relation.affinity = clampi(int(relation.affinity) + affinity_delta, -100, 100)
	relationships[other_id] = relation
	_world.log_event("%s relationship to %s trust: %s -> %s" % [agent_name, other_id, old_trust, relation.trust])

func can_send_message(target_id: String, message: String) -> bool:
	if message.strip_edges().is_empty(): return false
	var previous: Dictionary = _last_messages.get(target_id, {})
	if previous.get("message", "") == message and _world.world_tick - int(previous.get("tick", -999)) < 30: return false
	_last_messages[target_id] = {"message": message, "tick": _world.world_tick}
	return true

func set_wander_destination(destination: Vector2) -> void:
	current_action = "wander"; _destination = destination; update_status("Wandering — %s" % current_goal)

func set_talk_target(target: WorldAgent, message: String) -> void:
	current_action = "talk"; _destination = target.global_position; update_status("To %s: %s" % [target.agent_name, message])

func wait_safely() -> void:
	current_action = "wait"; velocity = Vector2.ZERO; update_status("Waiting — %s" % current_goal)

func eat_apple() -> void:
	hunger = max(0, hunger - 50); current_action = "wait"; update_status("Ate Apple — hunger %s" % hunger)

func update_status(text: String) -> void:
	$NameLabel.text = "%s  (H:%s E:%s)" % [agent_name, hunger, energy]
	$StatusLabel.text = text
