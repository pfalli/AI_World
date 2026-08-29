class_name SocialRules
extends RefCounted

# Deterministic social consequences. The AI can choose behaviour and dialogue, but only
# these world-side rules alter relationship state or decide who owns a targeted event.
static func adjust_relation(current: Dictionary, trust_delta: int, affinity_delta: int, anger_delta: int, familiarity_delta: int) -> Dictionary:
	return {
		"trust": clampi(int(current.get("trust", 0)) + trust_delta, -100, 100),
		"affinity": clampi(int(current.get("affinity", 0)) + affinity_delta, -100, 100),
		"anger": clampi(int(current.get("anger", 0)) + anger_delta, 0, 100),
		"familiarity": clampi(int(current.get("familiarity", 0)) + familiarity_delta, 0, 100),
	}

static func is_targeted_at(event: Dictionary, observer_id: String) -> bool:
	return str(event.get("target_agent_id", "")) == observer_id

static func message_consequence(text: String) -> Dictionary:
	var normalized := text.to_lower()
	if "sorry" in normalized or "apolog" in normalized:
		return {"trust": 3, "affinity": 2, "anger": -5, "familiarity": 2, "reason": "apology"}
	if "thank" in normalized:
		return {"trust": 1, "affinity": 3, "anger": -2, "familiarity": 2, "reason": "thanks"}
	if "idiot" in normalized or "stupid" in normalized or "hate" in normalized:
		return {"trust": -3, "affinity": -4, "anger": 6, "familiarity": 1, "reason": "insult"}
	if "cannot help" in normalized or "can't help" in normalized or "refuse" in normalized:
		return {"trust": -1, "affinity": -2, "anger": 2, "familiarity": 1, "reason": "refusal"}
	return {"trust": 0, "affinity": 1, "anger": -1, "familiarity": 3, "reason": "conversation"}
