class_name ActionValidator
extends RefCounted

static func validate(primitive: Dictionary, context: Dictionary) -> Dictionary:
	var type := str(primitive.get("type", ""))
	var target: Dictionary = context.get("target", {})
	var parameters: Dictionary = primitive.get("parameters", {})
	var distance := float(context.get("distance", 0.0))
	var interaction_distance := float(context.get("interaction_distance", 0.0))
	var inventory: Dictionary = context.get("inventory", {})
	if type == "WAIT": return _valid()
	# CONSUME is inventory-only; it deliberately has no world target.
	if type == "CONSUME":
		if int(inventory.get(str(parameters.get("item", "")), 0)) < 1: return _invalid("item is not in inventory")
		return _valid()
	if type == "MOVE_TO":
		if str(primitive.get("target_id", "")) == "exploration" or not target.is_empty(): return _valid()
		return _invalid("target does not exist")
	if target.is_empty(): return _invalid("target does not exist")
	if type == "PICK_UP":
		if str(target.get("type", "")) != "berry_bush": return _invalid("target is not gatherable")
		if int(target.get("berries_available", 0)) <= 0: return _invalid("resource is empty")
		if distance > interaction_distance: return _invalid("too far away")
		return _valid()
	if type == "USE":
		if str(parameters.get("item", "")) != "water" or str(target.get("type", "")) != "water": return _invalid("target cannot be used as water")
		if distance > interaction_distance: return _invalid("too far away")
		return _valid()
	if type == "DROP":
		if str(target.get("type", "")) != "agent": return _invalid("recipient is not an agent")
		if distance > interaction_distance: return _invalid("too far away")
		if int(inventory.get(str(parameters.get("item", "")), 0)) < int(parameters.get("quantity", 1)): return _invalid("item is not in inventory")
		return _valid()
	if type == "SPEAK":
		if str(target.get("type", "")) != "agent": return _invalid("recipient is not an agent")
		if distance > interaction_distance: return _invalid("too far away")
		if str(parameters.get("message", "")).strip_edges().is_empty(): return _invalid("message is empty")
		return _valid()
	return _invalid("unknown primitive")

static func _valid() -> Dictionary: return {"valid": true, "reason": "valid"}
static func _invalid(reason: String) -> Dictionary: return {"valid": false, "reason": reason}

static func failure_observation(primitive: Dictionary, reason: String) -> String:
	return "I cannot %s: %s." % [str(primitive.get("type", "action")).to_lower().replace("_", " "), reason]
