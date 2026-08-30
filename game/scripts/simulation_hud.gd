class_name SimulationHUD
extends CanvasLayer

var world: Node2D
var app: Node
var world_viewport: SubViewportContainer
var clock_label: Label
var world_label: Label
var status_label: Label
var stats_label: Label
var event_feed: TextEdit
var inspector: TextEdit
var inspector_panel: PanelContainer
var history_panel: PanelContainer
var history_text: TextEdit
var history_filter: OptionButton
var debug_panel: TextEdit
var pause_button: Button
var _last_agent: WorldAgent

func setup(world_node: Node2D, app_node: Node, viewport: SubViewportContainer) -> void:
	world = world_node
	app = app_node
	world_viewport = viewport
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	world.structured_event_recorded.connect(_on_history_event)
	for record: Dictionary in world.world_history: _append_event(record)

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Leave the forest itself clickable; only visible HUD controls consume input.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := PanelContainer.new(); header.position = Vector2(10, 10); header.size = Vector2(940, 102); header.add_theme_stylebox_override("panel", UIFactory.panel(Color(0.02, 0.06, 0.04, 0.94))); root.add_child(header)
	var header_box := VBoxContainer.new(); header_box.add_theme_constant_override("separation", 7); header.add_child(header_box)
	var table := HBoxContainer.new(); table.add_theme_constant_override("separation", 7); header_box.add_child(table)
	var brand := _header_cell("APPLICATION", "AI WORLD")
	brand.add_theme_font_size_override("font_size", 18)
	table.add_child(brand)
	world_label = _header_cell("WORLD", world.experiment_config.world_name if world.experiment_config != null else "Forest Experiment")
	table.add_child(world_label)
	clock_label = _header_cell("WORLD TIME", "Day 1 · 00:00", Color(0.72, 0.88, 0.69, 1))
	table.add_child(clock_label)
	stats_label = _header_cell("SIMULATION", "Agents: 0 · Resources: 0", Color(0.75, 0.89, 0.73, 1))
	table.add_child(stats_label)
	var controls := HBoxContainer.new(); controls.alignment = BoxContainer.ALIGNMENT_END; controls.add_theme_constant_override("separation", 8); header_box.add_child(controls)
	status_label = UIFactory.label("RUNNING", 12, Color(0.66, 0.9, 0.62, 1)); status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; controls.add_child(status_label)
	pause_button = UIFactory.button("PAUSE"); pause_button.custom_minimum_size = Vector2(88, 30); pause_button.pressed.connect(_toggle_pause); controls.add_child(pause_button)
	var speed := OptionButton.new(); speed.custom_minimum_size = Vector2(76, 30)
	for option in ["1x", "2x", "4x", "16x"]: speed.add_item(option)
	speed.select([1.0, 2.0, 4.0, 16.0].find(world.simulation_speed)); speed.item_selected.connect(func(index: int) -> void: world.set_simulation_speed([1.0, 2.0, 4.0, 16.0][index])); controls.add_child(speed)
	var history := UIFactory.button("HISTORY"); history.custom_minimum_size = Vector2(86, 30); history.pressed.connect(func() -> void: history_panel.visible = not history_panel.visible; if history_panel.visible: _refresh_history()); controls.add_child(history)
	var debug := UIFactory.button("DEBUG"); debug.custom_minimum_size = Vector2(74, 30); debug.pressed.connect(func() -> void: debug_panel.visible = not debug_panel.visible; if debug_panel.visible: _refresh_debug()); controls.add_child(debug)

	var event_panel := PanelContainer.new(); event_panel.position = Vector2(722, 122); event_panel.size = Vector2(228, 178); event_panel.add_theme_stylebox_override("panel", UIFactory.panel()); root.add_child(event_panel)
	var event_box := VBoxContainer.new(); event_panel.add_child(event_box)
	event_box.add_child(UIFactory.label("WORLD EVENTS", 15))
	event_feed = TextEdit.new(); event_feed.editable = false; event_feed.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; event_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL; event_feed.add_theme_color_override("background_color", Color(0.01, 0.03, 0.02, 0.0)); event_box.add_child(event_feed)

	inspector_panel = PanelContainer.new(); inspector_panel.position = Vector2(722, 312); inspector_panel.size = Vector2(228, 310); inspector_panel.visible = false; inspector_panel.add_theme_stylebox_override("panel", UIFactory.panel()); root.add_child(inspector_panel)
	var inspector_box := VBoxContainer.new(); inspector_panel.add_child(inspector_box)
	var inspector_header := HBoxContainer.new(); inspector_box.add_child(inspector_header)
	var inspector_title := UIFactory.label("AGENT INSPECTOR", 15); inspector_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inspector_header.add_child(inspector_title)
	var close := Button.new(); close.text = "×"; close.custom_minimum_size = Vector2(28, 24); close.pressed.connect(_close_inspector); inspector_header.add_child(close)
	inspector = TextEdit.new(); inspector.editable = false; inspector.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL; inspector.add_theme_color_override("background_color", Color(0.01, 0.03, 0.02, 0.0)); inspector_box.add_child(inspector)

	history_panel = PanelContainer.new(); history_panel.position = Vector2(130, 122); history_panel.size = Vector2(610, 470); history_panel.visible = false; history_panel.add_theme_stylebox_override("panel", UIFactory.panel(Color(0.02, 0.065, 0.045, 0.98))); root.add_child(history_panel)
	var history_box := VBoxContainer.new(); history_panel.add_child(history_box)
	var history_header := HBoxContainer.new(); history_box.add_child(history_header)
	var history_title := UIFactory.label("WORLD HISTORY", 20); history_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; history_header.add_child(history_title)
	var close_history := Button.new(); close_history.text = "×"; close_history.pressed.connect(func() -> void: history_panel.visible = false); history_header.add_child(close_history)
	history_filter = OptionButton.new()
	for option in ["ALL", "SOCIAL", "RESOURCES", "DISCOVERY", "AGENTS"]:
		history_filter.add_item(option)
	history_filter.item_selected.connect(func(_index: int) -> void: _refresh_history())
	history_box.add_child(history_filter)
	history_text = TextEdit.new(); history_text.editable = false; history_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; history_text.size_flags_vertical = Control.SIZE_EXPAND_FILL; history_box.add_child(history_text)

	debug_panel = TextEdit.new(); debug_panel.position = Vector2(18, 350); debug_panel.size = Vector2(584, 242); debug_panel.visible = false; debug_panel.editable = false; debug_panel.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; debug_panel.add_theme_color_override("background_color", Color(0.01, 0.025, 0.02, 0.95)); debug_panel.add_theme_color_override("font_color", Color(0.75, 1, 0.82, 1)); root.add_child(debug_panel)

func _header_cell(caption: String, value: String, color := Color(0.92, 0.98, 0.86, 1)) -> Label:
	var cell := UIFactory.label("%s\n%s" % [caption, value], 14, color)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.02, 1))
	cell.add_theme_constant_override("outline_size", 1)
	return cell

func _process(_delta: float) -> void:
	if world == null: return
	clock_label.text = "WORLD TIME\n" + world.world_clock()
	world_label.text = "WORLD\n" + (world.experiment_config.world_name if world.experiment_config != null else "Forest Experiment")
	pause_button.text = "RESUME" if world.simulation_paused else "PAUSE"
	status_label.text = "PAUSED" if world.simulation_paused else "RUNNING"
	status_label.add_theme_color_override("font_color", Color(1, 0.82, 0.48, 1) if world.simulation_paused else Color(0.66, 0.9, 0.62, 1))
	stats_label.text = "SIMULATION\n%s agents · %s resources · %s events" % [world.agents.get_child_count(), world.environment_entities.size(), world.world_history.size()]
	if world.selected_agent != _last_agent:
		_last_agent = world.selected_agent
		inspector_panel.visible = _last_agent != null
	if _last_agent != null and is_instance_valid(_last_agent): _refresh_inspector(_last_agent)
	if debug_panel.visible: _refresh_debug()

func _toggle_pause() -> void:
	world.set_simulation_paused(not world.simulation_paused)

func _close_inspector() -> void:
	world.selected_agent = null
	_last_agent = null
	inspector_panel.visible = false

func _on_history_event(record: Dictionary) -> void:
	_append_event(record)
	if history_panel.visible: _refresh_history()

func _append_event(record: Dictionary) -> void:
	event_feed.text += "%s  %s\n" % [str(record.get("time", "")), str(record.get("description", ""))]
	var lines := event_feed.get_line_count()
	if lines > 12:
		var retained: PackedStringArray = event_feed.text.split("\n", false).slice(-12)
		event_feed.text = "\n".join(retained) + "\n"
	event_feed.scroll_vertical = event_feed.get_line_count()

func _refresh_inspector(agent: WorldAgent) -> void:
	var inventory_lines: Array[String] = []
	for item in agent.inventory:
		if int(agent.inventory[item]) > 0: inventory_lines.append("%s x%s" % [item.capitalize(), agent.inventory[item]])
	var relation_lines: Array[String] = []
	for other_id in agent.relationships:
		var relation: Dictionary = agent.relationships[other_id]
		relation_lines.append("%s  Trust %s  Affinity %s  Anger %s" % [other_id.capitalize(), relation.get("trust", 0), relation.get("affinity", 0), relation.get("anger", 0)])
	var memory_lines: Array[String] = []
	for memory: Dictionary in agent.memories.slice(-4): memory_lines.append("• %s" % str(memory.get("description", "")))
	var p := agent.personality
	inspector.text = "%s\n\nCURRENT THOUGHT\n%s\n\nCURRENT GOAL  %s\nCURRENT ACTION  %s\n\nNEEDS\nHunger %s   Thirst %s\nEnergy %s   Social %s\nSafety %s\n\nPERSONALITY\nSociability %s  Generosity %s\nAggression %s  Curiosity %s\nEmpathy %s  Selfishness %s\n\nINVENTORY\n%s\n\nRELATIONSHIPS\n%s\n\nIMPORTANT MEMORIES\n%s\n\nAI\nProvider: server-configured\nLast intent: %s" % [agent.agent_name.to_upper(), agent.last_reason if not agent.last_reason.is_empty() else agent.initial_goal, agent.current_goal, agent.current_action, agent.hunger, agent.thirst, agent.energy, agent.social_need, agent.safety, round(float(p.get("sociability", 0.0)) * 100), round(float(p.get("generosity", 0.0)) * 100), round(float(p.get("aggression", 0.0)) * 100), round(float(p.get("curiosity", 0.0)) * 100), round(float(p.get("empathy", 0.0)) * 100), round(float(p.get("selfishness", 0.0)) * 100), "\n".join(inventory_lines) if not inventory_lines.is_empty() else "Empty", "\n".join(relation_lines) if not relation_lines.is_empty() else "None yet", "\n".join(memory_lines) if not memory_lines.is_empty() else "None yet", agent.current_action]

func _refresh_history() -> void:
	var filter := history_filter.get_item_text(history_filter.selected).to_lower()
	var lines: Array[String] = []
	for record: Dictionary in world.world_history:
		var type := str(record.get("type", ""))
		if filter != "all" and not ((filter == "resources" and type == "resource") or (filter == "agents" and type == "agent") or filter == type): continue
		lines.append("%s  %s" % [record.get("time", ""), record.get("description", "")])
	history_text.text = "\n".join(lines) if not lines.is_empty() else "No matching events yet."

func _refresh_debug() -> void:
	debug_panel.text = "DEVELOPER MODE\n" + "\n".join(world.raw_log.slice(-18))
