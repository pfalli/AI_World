extends SceneTree

const SessionScript := preload("res://scripts/conversation_session.gd")
const SocialRulesScript := preload("res://scripts/social_rules.gd")

func _init() -> void:
	var session := SessionScript.start("alice", "bob", 1)
	for tick in range(1, 7): session = SessionScript.record(session, "alice" if tick % 2 else "bob", tick, 6)
	assert(bool(session.ended))
	assert(not SessionScript.is_available(session, 7, 6, 45))
	var active := SessionScript.start("alice", "charlie", 1)
	assert(SessionScript.is_available(active, 2, 6, 45))
	assert(not SessionScript.is_available(active, 46, 6, 45))
	var relation := SocialRulesScript.adjust_relation({"trust": 20, "affinity": 5, "anger": 10, "familiarity": 2}, 5, 3, -4, 6)
	assert(int(relation.trust) == 25)
	assert(int(relation.anger) == 6)
	assert(int(relation.familiarity) == 8)
	var directed_event := {"type": "gift", "target_agent_id": "alice"}
	assert(SocialRulesScript.is_targeted_at(directed_event, "alice"))
	assert(not SocialRulesScript.is_targeted_at(directed_event, "charlie"))
	var apology := SocialRulesScript.message_consequence("I am sorry about that.")
	assert(int(apology.trust) > 0)
	assert(int(apology.anger) < 0)
	var insult := SocialRulesScript.message_consequence("You are an idiot.")
	assert(int(insult.trust) < 0)
	assert(int(insult.anger) > 0)
	quit()
