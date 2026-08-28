class_name WorldAgent
extends CharacterBody2D

@export var agent_id := "agent"
@export var agent_name := "Agent"
@export var hunger := 80
@export var thirst := 55
@export var energy := 100
@export var personality: Dictionary = {"friendliness": 0.5, "cooperation": 0.5, "curiosity": 0.5, "selfishness": 0.5, "aggression": 0.5}
@export var body_color := Color.WHITE
@export_file("*.png") var walk_sheet_path := "res://assets/character_variants/alice_4DirectionWalk.png"
@export_file("*.png") var idle_sheet_path := "res://assets/character_variants/alice_4DirectionIdle.png"
@export var decision_interval := 12
@export var talk_cooldown_ticks := 15
@export var max_memories := 100

const ACTIONS := ["wander", "explore", "gather", "eat", "drink", "give", "talk", "rest", "wait", "go_to_known"]
const GOALS := ["find_food", "find_water", "rest", "explore", "socialize", "help_agent", "idle"]
const SPEED := 115.0
const CONTEXT_LIMIT := 8
enum ActionState { IDLE, APPROACHING_TARGET, EXECUTING, COMPLETED, FAILED }
var current_action := "wait"
var current_goal := "idle"
var action_state := ActionState.IDLE
var _action_sequence := 0
var _active_action_id := 0
var _active_action_name := ""
var relationships: Dictionary = {}
var inventory: Dictionary = {"berry": 0}
var known_locations: Dictionary = {}
var visited_cells: Dictionary = {}
var memories: Array[Dictionary] = []
var recent_events: Array[Dictionary] = []
var pending_messages: Array[Dictionary] = []
var last_reason := ""
var last_decision_tick := -999
var _decision_reason := "INITIAL"
var _important_event := false
var _action_complete := true
var _talked_at: Dictionary = {}
var _last_messages: Dictionary = {}
var _decision_in_flight := false
var _destination := Vector2.ZERO
var _pending_intent: Dictionary = {}
var _urgent_hunger_armed := true
var _urgent_thirst_armed := true
var ai_request_count := 0
var _client: AIClient
var _world: Node
var _last_facing := "down"


func setup(world: Node, server_address: String) -> void:
	_world = world
	_client = AIClient.new()
	_client.server_url = server_address
	add_child(_client)
	_client.decision_received.connect(_on_decision_received)
	_client.request_failed.connect(_on_request_failed)
	_setup_visuals()
	update_status("Waiting")
	_decision_loop()

func _physics_process(_delta: float) -> void:
	if current_action == "wander" or current_action == "talk" or action_state == ActionState.APPROACHING_TARGET:
		velocity = global_position.direction_to(_destination) * SPEED
		if global_position.distance_to(_destination) < 5.0:
			velocity = Vector2.ZERO
			if action_state == ActionState.APPROACHING_TARGET: _world.arrived_at_target(self)
			elif current_action == "wander": mark_action_completed()
		move_and_slide()
		# Destinations remain simulation-owned; this is a final world-edge guard only.
		global_position = Vector2(
			clampf(global_position.x, WorldConfig.MAP_BOUNDS.position.x, WorldConfig.MAP_BOUNDS.end.x),
			clampf(global_position.y, WorldConfig.MAP_BOUNDS.position.y, WorldConfig.MAP_BOUNDS.end.y)
		)
	_update_animation()

func _setup_visuals() -> void:
	var frames := SpriteFrames.new()
	var walk_sheet := load(walk_sheet_path) as Texture2D
	var idle_sheet := load(idle_sheet_path) as Texture2D
	# Pack layout: walk is 4 x 4 16x32px frames; idle is 6 x 7 16x32px frames.
	# The first four rows match the four walk directions.
	for row_direction in ["down", "left", "right", "up"]:
		frames.add_animation("walk_" + row_direction)
		frames.set_animation_speed("walk_" + row_direction, 6.0)
		for column in range(4):
			frames.add_frame("walk_" + row_direction, _atlas_frame(walk_sheet, column, ["down", "left", "right", "up"].find(row_direction)))
		frames.add_animation("idle_" + row_direction)
		frames.set_animation_speed("idle_" + row_direction, 3.0)
		for column in range(6):
			frames.add_frame("idle_" + row_direction, _atlas_frame(idle_sheet, column, ["down", "left", "right", "up"].find(row_direction)))
	$Visual.sprite_frames = frames
	$Visual.modulate = Color.WHITE
	$Visual.play("idle_down")
	$NameLabel.text = agent_name

func _atlas_frame(texture: Texture2D, column: int, row: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(column * 16, row * 32, 16, 32)
	return frame

func _update_animation() -> void:
	if velocity.length_squared() > 1.0:
		if absf(velocity.x) > absf(velocity.y): _last_facing = "right" if velocity.x > 0.0 else "left"
		else: _last_facing = "down" if velocity.y > 0.0 else "up"
		$Visual.play("walk_" + _last_facing)
	else:
		$Visual.play("idle_" + _last_facing)
	if $DebugLabel.visible:
		$DebugLabel.text = "%s  %s\n(%d, %d)" % [current_action, ActionState.keys()[action_state], global_position.x, global_position.y]

func set_debug_visible(value: bool) -> void:
	$DebugLabel.visible = value

func _decision_loop() -> void:
	while is_instance_valid(_world):
		var trigger := should_request_decision()
		if not trigger.is_empty():
			_decision_reason = trigger
			ai_request_count += 1
			_world.log_event("%s AI_REQUEST #%s reason=%s" % [agent_name, ai_request_count, trigger])
			_decision_in_flight = true
			_client.request_decision(_world.build_observation(self))
		await get_tree().create_timer(0.5).timeout

func should_request_decision() -> String:
	if _decision_in_flight: return ""
	if action_state == ActionState.APPROACHING_TARGET: return ""
	if not pending_messages.is_empty(): return "MESSAGE_RECEIVED"
	if _important_event: return "IMPORTANT_EVENT"
	if hunger >= 70 and _urgent_hunger_armed:
		_urgent_hunger_armed = false; return "HUNGER_URGENT"
	if thirst >= 70 and _urgent_thirst_armed:
		_urgent_thirst_armed = false; return "THIRST_URGENT"
	if _action_complete: return "ACTION_COMPLETE"
	if _world.world_tick - last_decision_tick >= decision_interval: return "DECISION_TIMEOUT"
	return ""

func _on_decision_received(decision: Dictionary) -> void:
	_decision_in_flight = false
	last_decision_tick = _world.world_tick
	_important_event = false
	_action_complete = false
	# Long-running rest/talk actions end before the next committed intent starts.
	if _active_action_id != 0: mark_action_completed()
	for pending in pending_messages: pending.pending = false
	var action := str(decision.get("action", "wait"))
	current_goal = str(decision.get("goal", "idle"))
	if not ACTIONS.has(action): action = "wait"
	if not GOALS.has(current_goal): current_goal = "idle"
	last_reason = str(decision.get("reason", "No reason provided."))
	start_action(action)
	_world.log_event("%s decision %s target=%s" % [agent_name, action.to_upper(), str(decision.get("target_id", ""))])
	_world.execute_intent(self, action, str(decision.get("target_id", "")), str(decision.get("message", "")), decision.get("parameters", {}))
	pending_messages.clear()
	_world.show_agent_info(self)

func _on_request_failed(error_text: String) -> void:
	_decision_in_flight = false
	last_decision_tick = _world.world_tick
	wait_safely()
	last_reason = "AI unavailable; safe fallback."
	_world.log_event("%s AI fallback: %s" % [agent_name, error_text])

func receive_social_event(event: Dictionary) -> void:
	recent_events.append(event)
	if recent_events.size() > CONTEXT_LIMIT: recent_events.pop_front()
	var event_type := str(event.get("type", "event"))
	var actor_id := str(event.get("actor_id", ""))
	if event_type == "message" and str(event.get("target_agent_id", "")) == agent_id:
		var pending: Dictionary = {"speaker_id": actor_id, "target_id": agent_id, "text": str(event.get("text", "")), "tick": int(event.get("tick", 0)), "pending": true}
		pending_messages.append(pending)
		remember({"type": "received_message", "speaker_id": actor_id, "listener_id": agent_id, "message": pending.text, "description": "%s said: %s" % [str(event.get("actor_name", actor_id)), pending.text], "importance": 5})
		_world.log_event("%s pending messages: %s" % [agent_name, pending_messages.size()])
	elif event_type == "resource_taken" and actor_id != agent_id:
		var importance: int = 8 if hunger > 70 else 3
		var description: String = "%s took the only available food while I was very hungry." % str(event.get("actor_name", actor_id)) if hunger > 70 else "%s took an apple." % str(event.get("actor_name", actor_id))
		remember({"type": "observed_action", "actor_id": actor_id, "target_id": str(event.get("target_id", "")), "description": description, "importance": importance})
		if hunger > 50: change_relationship(actor_id, -15, -5)
		_important_event = true
		_world.log_event("%s interpreted event importance=%s" % [agent_name, importance])

func remember(data: Dictionary) -> void:
	var memory: Dictionary = {"id": "%s_%s_%s" % [agent_id, _world.world_tick, memories.size()], "type": str(data.get("type", "event")), "actor_id": data.get("actor_id", null), "target_id": data.get("target_id", null), "observer_id": agent_id, "speaker_id": data.get("speaker_id", null), "listener_id": data.get("listener_id", null), "message": data.get("message", null), "description": str(data.get("description", "Event")), "importance": clampi(int(data.get("importance", 1)), 1, 10), "tick": _world.world_tick}
	memories.append(memory)
	if memories.size() > max_memories:
		memories.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.importance) < int(b.importance) or (a.importance == b.importance and int(a.tick) < int(b.tick)))
		memories.pop_front()
	_world.log_event("%s memory created: %s" % [agent_name, memory.description])

func relevant_memories(visible_ids: Array) -> Array[Dictionary]:
	var scored: Array[Dictionary] = []
	for memory: Dictionary in memories:
		var relevance := 4 if visible_ids.has(memory.get("actor_id", "")) else 0
		var age: int = maxi(0, _world.world_tick - int(memory.tick))
		var copy: Dictionary = memory.duplicate()
		copy["_score"] = int(memory.importance) * 10 + relevance - mini(age, 30)
		scored.append(copy)
	scored.sort_custom(func(a: Dictionary, b: Dictionary): return int(a._score) > int(b._score))
	return scored.slice(0, CONTEXT_LIMIT)

func change_relationship(other_id: String, trust_delta: int, affinity_delta: int) -> void:
	if other_id.is_empty() or other_id == agent_id: return
	var relation: Dictionary = relationships.get(other_id, {"trust": 0, "affinity": 0})
	var old_trust: int = int(relation.trust)
	relation.trust = clampi(old_trust + trust_delta, -100, 100)
	relation.affinity = clampi(int(relation.affinity) + affinity_delta, -100, 100)
	relationships[other_id] = relation
	_world.log_event("%s relationship %s trust %s -> %s" % [agent_name, other_id, old_trust, relation.trust])

func can_talk_to(target_id: String, message: String) -> bool:
	if message.strip_edges().is_empty(): return false
	var previous: Dictionary = _last_messages.get(target_id, {})
	var normalized := message.to_lower().strip_edges()
	if previous.get("normalized", "") == normalized and _world.world_tick - int(previous.get("tick", -999)) < 30: return false
	var cooldown_tick: int = int(_talked_at.get(target_id, -999))
	if _world.world_tick - cooldown_tick < talk_cooldown_ticks and not has_pending_from(target_id): return false
	_last_messages[target_id] = {"normalized": normalized, "tick": _world.world_tick}
	_talked_at[target_id] = _world.world_tick
	return true

func has_pending_from(other_id: String) -> bool:
	for pending: Dictionary in pending_messages:
		if pending.speaker_id == other_id: return true
	return false

func set_wander_destination(destination: Vector2) -> void:
	current_action = "wander"; _destination = destination; update_status("Wandering — %s" % current_goal)

func set_talk_target(target: WorldAgent, message: String) -> void:
	current_action = "talk"; _destination = target.global_position; _action_complete = false; update_status("To %s: %s" % [target.agent_name, message])

func wait_safely() -> void:
	velocity = Vector2.ZERO
	if _active_action_id != 0: mark_action_completed()
	else: current_action = "wait"; action_state = ActionState.IDLE; _action_complete = false; update_status("Waiting — %s" % current_goal)

func start_action(action: String) -> void:
	_action_sequence += 1
	_active_action_id = _action_sequence
	_active_action_name = action
	current_action = action
	action_state = ActionState.EXECUTING
	_action_complete = false
	_world.log_event("%s ACTION #%s %s started" % [agent_name, _active_action_id, action.to_upper()])

func begin_approach(intent: Dictionary, destination: Vector2, target_name: String) -> void:
	_pending_intent = intent; _destination = destination; current_action = str(intent.action); action_state = ActionState.APPROACHING_TARGET; _action_complete = false
	update_status("Approaching %s" % target_name)
	_world.log_event("%s state=APPROACHING_TARGET target=%s" % [agent_name, target_name])

func take_pending_intent() -> Dictionary:
	var intent := _pending_intent; _pending_intent = {}; return intent

func mark_action_completed() -> void:
	if _active_action_id == 0 or action_state == ActionState.COMPLETED or action_state == ActionState.IDLE: return
	var finished_id := _active_action_id
	var finished_name := _active_action_name
	action_state = ActionState.COMPLETED; _action_complete = true; _pending_intent = {}; _destination = global_position
	_active_action_id = 0; _active_action_name = ""; current_action = "wait"; velocity = Vector2.ZERO
	_world.log_event("%s ACTION #%s %s completed" % [agent_name, finished_id, finished_name.to_upper()])

func mark_action_failed(reason: String) -> void:
	if _active_action_id == 0 or action_state == ActionState.FAILED or action_state == ActionState.IDLE: return
	var failed_id := _active_action_id
	var failed_name := _active_action_name
	action_state = ActionState.FAILED; _action_complete = true; _pending_intent = {}; _destination = global_position
	_active_action_id = 0; _active_action_name = ""; current_action = "wait"; velocity = Vector2.ZERO
	_world.log_event("%s ACTION #%s %s failed: %s" % [agent_name, failed_id, failed_name.to_upper(), reason])

func update_status(text: String) -> void:
	$NameLabel.text = agent_name

func add_item(item: String, quantity: int) -> void:
	inventory[item] = int(inventory.get(item, 0)) + quantity

func remove_item(item: String, quantity: int) -> bool:
	if int(inventory.get(item, 0)) < quantity: return false
	inventory[item] = int(inventory.get(item, 0)) - quantity
	return true

func has_item(item: String, quantity := 1) -> bool:
	return int(inventory.get(item, 0)) >= quantity

func get_item_count(item: String) -> int:
	return int(inventory.get(item, 0))

func remember_location(entity: Dictionary) -> bool:
	var id := str(entity.id)
	var is_new := not known_locations.has(id)
	known_locations[id] = {"entity_id": id, "entity_type": str(entity.type), "last_known_position": entity.world_position, "last_seen_tick": _world.world_tick}
	return is_new

func apply_needs() -> void:
	hunger = clampi(hunger + int(WorldConfig.HUNGER_PER_TICK), 0, 100)
	thirst = clampi(thirst + int(WorldConfig.THIRST_PER_TICK), 0, 100)
	if current_action == "rest": energy = mini(100, energy + int(WorldConfig.REST_ENERGY_PER_TICK))
	elif current_action != "wait": energy = maxi(0, energy - int(WorldConfig.ENERGY_ACTIVE_PER_TICK))
	if hunger <= 55: _urgent_hunger_armed = true
	if thirst <= 55: _urgent_thirst_armed = true
