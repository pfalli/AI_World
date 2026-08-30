class_name AppManager
extends Node

const WORLD_SCENE := preload("res://scenes/world.tscn")
const HUD_SCRIPT := preload("res://scripts/simulation_hud.gd")

var experiment: ExperimentConfig = ExperimentConfig.default_scenario()
var world: Node2D
var world_viewport: SubViewportContainer
var world_render_target: SubViewport
var _ui_layer := CanvasLayer.new()
var _screen: Control
var _agent_index := 0
var _agent_name: LineEdit
var _agent_background: TextEdit
var _agent_goal: TextEdit
var _personality_fields: Dictionary = {}

func _ready() -> void:
	_ui_layer.name = "UI"
	_ui_layer.layer = 20
	add_child(_ui_layer)
	_show_main_menu()

func _make_screen() -> Control:
	if is_instance_valid(_screen): _screen.queue_free()
	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_screen)
	return _screen

func _background(root: Control) -> void:
	var color := ColorRect.new()
	color.color = Color(0.015, 0.045, 0.03, 1)
	color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(color)
	var glow := ColorRect.new()
	glow.color = Color(0.07, 0.19, 0.10, 0.36)
	glow.position = Vector2(80, 70)
	glow.size = Vector2(800, 500)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)

func _center_panel(root: Control, size := Vector2(550, 460)) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = (Vector2(960, 640) - size) * 0.5
	panel.size = size
	panel.add_theme_stylebox_override("panel", UIFactory.panel())
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box

func _show_main_menu() -> void:
	var root := _make_screen()
	_background(root)
	var box := _center_panel(root, Vector2(560, 430))
	var title := UIFactory.label("AI WORLD", 42, Color(0.92, 1, 0.82, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tagline := UIFactory.label("A living world populated by autonomous AI agents.", 19, Color(0.72, 0.9, 0.7, 1))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)
	var divider := HSeparator.new()
	box.add_child(divider)
	var description := UIFactory.label("Create a world. Create its inhabitants. Give them different personalities and minds. Then stop controlling them and watch what happens.\n\nAgents perceive their environment, remember events, form relationships, pursue goals and make their own decisions.", 15)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(description)
	var spacer := Control.new(); spacer.custom_minimum_size.y = 8; box.add_child(spacer)
	var create := UIFactory.button("CREATE WORLD")
	create.pressed.connect(_show_world_setup)
	box.add_child(create)
	var about := UIFactory.button("ABOUT")
	about.pressed.connect(_show_about)
	box.add_child(about)

func _show_about() -> void:
	var root := _make_screen()
	_background(root)
	var box := _center_panel(root, Vector2(560, 380))
	box.add_child(UIFactory.label("ABOUT AI WORLD", 28))
	box.add_child(UIFactory.label("AI World is an observer experience. You configure an experiment, then autonomous inhabitants make their own validated decisions inside the forest.\n\nYou control conditions and simulation speed—not the inhabitants.", 16))
	var back := UIFactory.button("BACK")
	back.pressed.connect(_show_main_menu)
	box.add_child(back)

func _show_world_setup() -> void:
	var root := _make_screen()
	_background(root)
	var box := _center_panel(root, Vector2(560, 520))
	box.add_child(UIFactory.label("CREATE WORLD", 28))
	box.add_child(UIFactory.label("Configure the starting conditions for this experiment.", 14, Color(0.7, 0.84, 0.68, 1)))
	box.add_child(UIFactory.field_label("World name"))
	var name := LineEdit.new(); name.text = experiment.world_name; box.add_child(name)
	box.add_child(UIFactory.field_label("Environment"))
	var environment := OptionButton.new(); environment.add_item("Forest"); environment.selected = 0; box.add_child(environment)
	box.add_child(UIFactory.field_label("Number of agents"))
	var count := SpinBox.new(); count.min_value = 1; count.max_value = 6; count.step = 1; count.value = experiment.agents.size(); box.add_child(count)
	box.add_child(UIFactory.field_label("Simulation speed"))
	var speed := OptionButton.new()
	for option in ["1x", "2x", "4x", "16x"]: speed.add_item(option)
	speed.select([1.0, 2.0, 4.0, 16.0].find(experiment.simulation_speed)); box.add_child(speed)
	box.add_child(UIFactory.field_label("Food scarcity"))
	var scarcity := OptionButton.new()
	for option in ["Low", "Medium", "High"]: scarcity.add_item(option)
	scarcity.select(["Low", "Medium", "High"].find(experiment.food_scarcity)); box.add_child(scarcity)
	var buttons := HBoxContainer.new(); buttons.add_theme_constant_override("separation", 10); box.add_child(buttons)
	var back := UIFactory.button("BACK"); back.size_flags_horizontal = Control.SIZE_EXPAND_FILL; back.pressed.connect(_show_main_menu); buttons.add_child(back)
	var next := UIFactory.button("NEXT"); next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(func() -> void:
		experiment.world_name = name.text.strip_edges() if not name.text.strip_edges().is_empty() else "Forest Experiment"
		experiment.environment = environment.get_item_text(environment.selected)
		experiment.simulation_speed = [1.0, 2.0, 4.0, 16.0][speed.selected]
		experiment.food_scarcity = scarcity.get_item_text(scarcity.selected)
		while experiment.agents.size() < int(count.value): experiment.agents.append(AgentConfig.defaults(experiment.agents.size()))
		while experiment.agents.size() > int(count.value): experiment.agents.pop_back()
		_agent_index = mini(_agent_index, experiment.agents.size() - 1)
		_show_agent_setup())
	buttons.add_child(next)

func _show_agent_setup() -> void:
	var root := _make_screen()
	_background(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(30, 18); panel.size = Vector2(900, 604)
	panel.add_theme_stylebox_override("panel", UIFactory.panel())
	root.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box)
	var config := experiment.agents[_agent_index]
	var title_row := HBoxContainer.new(); box.add_child(title_row)
	var title := UIFactory.label("CREATE INHABITANTS", 22); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_row.add_child(title)
	title_row.add_child(UIFactory.label("%s agent%s" % [experiment.agents.size(), "s" if experiment.agents.size() != 1 else ""], 13, Color(0.7, 0.84, 0.68, 1)))
	box.add_child(UIFactory.label("Select an inhabitant to edit their real starting personality and state.", 13, Color(0.7, 0.84, 0.68, 1)))
	var selector_row := HBoxContainer.new(); selector_row.add_theme_constant_override("separation", 7); box.add_child(selector_row)
	var selector_group := ButtonGroup.new()
	for index in range(experiment.agents.size()):
		var agent_button := Button.new()
		agent_button.text = experiment.agents[index].agent_name
		agent_button.custom_minimum_size = Vector2(100, 34)
		agent_button.toggle_mode = true
		agent_button.button_group = selector_group
		agent_button.button_pressed = index == _agent_index
		agent_button.pressed.connect(_select_agent.bind(index))
		selector_row.add_child(agent_button)
	var add := Button.new(); add.text = "+ ADD"; add.custom_minimum_size = Vector2(78, 34)
	add.pressed.connect(func() -> void: _save_agent_form(); experiment.agents.append(AgentConfig.defaults(experiment.agents.size())); _agent_index = experiment.agents.size() - 1; _show_agent_setup())
	selector_row.add_child(add)
	var remove := Button.new(); remove.text = "REMOVE"; remove.custom_minimum_size = Vector2(82, 34); remove.disabled = experiment.agents.size() <= 1
	remove.pressed.connect(func() -> void: experiment.agents.remove_at(_agent_index); _agent_index = maxi(0, _agent_index - 1); _show_agent_setup())
	selector_row.add_child(remove)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 7); scroll.add_child(content)
	content.add_child(UIFactory.label("EDITING: %s" % config.agent_name.to_upper(), 16, Color(0.9, 0.98, 0.82, 1)))
	content.add_child(UIFactory.field_label("Name"))
	_agent_name = LineEdit.new(); _agent_name.text = config.agent_name; _agent_name.custom_minimum_size.y = 34; content.add_child(_agent_name)
	content.add_child(UIFactory.field_label("Personality"))
	content.add_child(UIFactory.label("Set tendencies, not commands. The agents still make their own decisions.", 12, Color(0.62, 0.78, 0.62, 1)))
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 8); content.add_child(grid)
	_personality_fields.clear()
	for key in ["sociability", "generosity", "aggression", "curiosity", "empathy", "selfishness"]:
		grid.add_child(_personality_control(key, float(config.personality.get(key, 0.5)) * 100.0))
	content.add_child(UIFactory.field_label("Background / short biography"))
	_agent_background = TextEdit.new(); _agent_background.custom_minimum_size.y = 62; _agent_background.text = config.background; content.add_child(_agent_background)
	content.add_child(UIFactory.field_label("Initial goal"))
	_agent_goal = TextEdit.new(); _agent_goal.custom_minimum_size.y = 50; _agent_goal.text = config.initial_goal; content.add_child(_agent_goal)
	content.add_child(UIFactory.label("AI: Server-configured provider (fake or OpenAI)", 13, Color(0.78, 0.86, 0.76, 1)))
	var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 10); box.add_child(controls)
	var back := UIFactory.button("BACK"); back.size_flags_horizontal = Control.SIZE_EXPAND_FILL; back.pressed.connect(_show_world_setup); controls.add_child(back)
	var start := UIFactory.button("START WORLD"); start.size_flags_horizontal = Control.SIZE_EXPAND_FILL; start.pressed.connect(func() -> void: _save_agent_form(); _show_loading()); controls.add_child(start)

func _select_agent(index: int) -> void:
	_save_agent_form()
	_agent_index = index
	_show_agent_setup()

func _personality_control(key: String, value: float) -> Control:
	var descriptions := {
		"sociability": "Seeks company",
		"generosity": "Shares resources",
		"aggression": "Confronts others",
		"curiosity": "Explores unknowns",
		"empathy": "Considers others",
		"selfishness": "Prioritizes self",
	}
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 54)
	card.add_theme_stylebox_override("panel", UIFactory.panel(Color(0.045, 0.11, 0.07, 0.84)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var labels := VBoxContainer.new()
	labels.custom_minimum_size = Vector2(98, 0)
	row.add_child(labels)
	labels.add_child(UIFactory.label(key.capitalize(), 13))
	labels.add_child(UIFactory.label(str(descriptions.get(key, "")), 10, Color(0.62, 0.77, 0.62, 1)))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = round(value)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "%s: %s" % [key.capitalize(), descriptions.get(key, "")]
	row.add_child(slider)
	var amount := UIFactory.label("%d" % round(value), 14, Color(0.92, 1, 0.82, 1))
	amount.custom_minimum_size = Vector2(30, 0)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)
	slider.value_changed.connect(func(next_value: float) -> void: amount.text = "%d" % round(next_value))
	_personality_fields[key] = slider
	return card

func _save_agent_form() -> void:
	if _agent_name == null or experiment.agents.is_empty(): return
	var config := experiment.agents[_agent_index]
	config.agent_name = _agent_name.text.strip_edges() if not _agent_name.text.strip_edges().is_empty() else "Agent %s" % (_agent_index + 1)
	config.agent_id = config.agent_name.to_lower().replace(" ", "_")
	config.background = _agent_background.text.strip_edges()
	config.initial_goal = _agent_goal.text.strip_edges()
	for key in _personality_fields: config.personality[key] = float((_personality_fields[key] as Range).value) / 100.0
	config.personality.friendliness = (float(config.personality.sociability) + float(config.personality.empathy)) * 0.5
	config.personality.cooperation = (float(config.personality.generosity) + float(config.personality.empathy)) * 0.5

func _show_loading() -> void:
	var root := _make_screen()
	_background(root)
	var box := _center_panel(root, Vector2(520, 390))
	box.add_child(UIFactory.label("CREATING WORLD...", 28))
	var status := UIFactory.label("• Initializing environment\n• Spawning resources\n• Creating inhabitants\n• Initializing agent state", 16)
	box.add_child(status)
	var enter := UIFactory.button("ENTER WORLD")
	enter.visible = false
	enter.pressed.connect(_enter_world)
	box.add_child(enter)
	call_deferred("_create_world", status, enter)

func _create_world(status: Label, enter: Button) -> void:
	# The autonomous world renders into its own screen region.  Application UI
	# remains outside this viewport, rather than being laid over the forest.
	world_viewport = SubViewportContainer.new()
	world_viewport.name = "WorldViewport"
	world_viewport.position = Vector2(10, 122)
	world_viewport.size = Vector2(700, 500)
	world_viewport.stretch = true
	add_child(world_viewport)
	world_render_target = SubViewport.new()
	world_render_target.size = Vector2i(700, 500)
	world_render_target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.add_child(world_render_target)
	world = WORLD_SCENE.instantiate()
	world.configure(experiment)
	world_render_target.add_child(world)
	world.get_node("HUD").visible = false
	status.text = "✓ Initializing environment\n✓ Spawning resources\n%s\n✓ Initializing agent state\n\nWORLD READY" % "\n".join(experiment.agents.map(func(agent: AgentConfig) -> String: return "✓ Creating %s" % agent.agent_name))
	enter.visible = true

func _enter_world() -> void:
	if is_instance_valid(_screen): _screen.queue_free()
	world.set_simulation_paused(false)
	var hud := HUD_SCRIPT.new()
	hud.name = "SimulationHUD"
	hud.setup(world, self, world_viewport)
	_ui_layer.add_child(hud)
