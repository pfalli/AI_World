class_name IntentPlanner
extends RefCounted

const MOVE_TO := "MOVE_TO"
const PICK_UP := "PICK_UP"
const DROP := "DROP"
const USE := "USE"
const CONSUME := "CONSUME"
const SPEAK := "SPEAK"
const WAIT := "WAIT"

func plan(intent: Dictionary) -> Array[Dictionary]:
	var target_id := str(intent.get("target_id", ""))
	var item := str(intent.get("item", "berry"))
	var message := str(intent.get("message", ""))
	match str(intent.get("intent", "wait")):
		"gather_resource": return [_primitive(MOVE_TO, target_id), _primitive(PICK_UP, target_id, {"item": item})]
		"drink_water": return [_primitive(MOVE_TO, target_id), _primitive(USE, target_id, {"item": "water"})]
		"consume_item": return [_primitive(CONSUME, "", {"item": item})]
		"speak", "socialize", "request_help", "offer_help", "confront": return [_primitive(MOVE_TO, target_id), _primitive(SPEAK, target_id, {"message": message})]
		"give_item": return [_primitive(MOVE_TO, target_id), _primitive(DROP, target_id, {"item": item, "quantity": int(intent.get("quantity", 1))})]
		"explore": return [_primitive(MOVE_TO, "exploration")]
		"rest": return [_primitive(WAIT, "", {"purpose": "rest"})]
		"avoid": return [_primitive(MOVE_TO, "exploration")]
		_: return [_primitive(WAIT)]

func describe(plan: Array[Dictionary]) -> String:
	var steps: Array[String] = []
	for primitive in plan:
		var target := str(primitive.get("target_id", ""))
		steps.append(str(primitive.type) + (" " + target if not target.is_empty() else ""))
	return " -> ".join(steps)

func _primitive(type: String, target_id := "", parameters: Dictionary = {}) -> Dictionary:
	return {"type": type, "target_id": target_id, "parameters": parameters}
