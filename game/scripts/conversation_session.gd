class_name ConversationSession
extends RefCounted

static func start(first: String, second: String, tick: int) -> Dictionary:
	return {"participants": [first, second], "topic": "general", "last_speaker": "", "turn_count": 0, "last_tick": tick, "ended": false}

static func record(session: Dictionary, speaker_id: String, tick: int, maximum_turns: int) -> Dictionary:
	var next := session.duplicate(true)
	next.last_speaker = speaker_id
	next.turn_count = int(next.get("turn_count", 0)) + 1
	next.last_tick = tick
	if int(next.turn_count) >= maximum_turns: next.ended = true
	return next

static func is_available(session: Dictionary, tick: int, maximum_turns: int, inactivity_ticks: int) -> bool:
	if session.is_empty(): return true
	if bool(session.get("ended", false)): return false
	if int(session.get("turn_count", 0)) >= maximum_turns: return false
	return tick - int(session.get("last_tick", tick)) < inactivity_ticks
