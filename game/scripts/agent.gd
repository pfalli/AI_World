class_name WorldAgent
extends CharacterBody2D

@export var agent_id := "agent"
@export var agent_name := "Agent"
@export var hunger := 80
@export var energy := 100
@export var personality: PackedStringArray
@export var body_color := Color.WHITE
@export var decision_interval := 5.0

const ACTIONS := ["take_apple", "talk", "wander", "wait"]
const SPEED := 115.0
var current_action := "wait"
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
	if not ACTIONS.has(action):
		action = "wait"
	_world.log_event("%s decided %s" % [agent_name, action.to_upper()])
	_world.execute_intent(self, action, str(decision.get("target_id", "")), str(decision.get("message", "")))

func _on_request_failed(error_text: String) -> void:
	wait_safely()
	update_status("Waiting (AI unavailable)")
	_world.log_event("%s AI fallback: %s" % [agent_name, error_text])

func set_wander_destination(destination: Vector2) -> void:
	current_action = "wander"
	_destination = destination
	update_status("Wandering")

func set_talk_target(target: WorldAgent, message: String) -> void:
	current_action = "talk"
	_destination = target.global_position
	update_status(message if not message.is_empty() else "Talking to %s" % target.agent_name)

func wait_safely() -> void:
	current_action = "wait"
	velocity = Vector2.ZERO
	update_status("Waiting")

func eat_apple() -> void:
	hunger = max(0, hunger - 50)
	current_action = "wait"
	update_status("Ate Apple — hunger %s" % hunger)

func update_status(text: String) -> void:
	$NameLabel.text = "%s  (H:%s E:%s)" % [agent_name, hunger, energy]
	$StatusLabel.text = text
