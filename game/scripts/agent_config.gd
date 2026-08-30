class_name AgentConfig
extends Resource

@export var agent_id := "agent"
@export var agent_name := "Agent"
@export var personality: Dictionary = {
	"sociability": 0.5, "generosity": 0.5, "aggression": 0.5,
	"curiosity": 0.5, "empathy": 0.5, "selfishness": 0.5,
	"friendliness": 0.5, "cooperation": 0.5,
}
@export_multiline var background := ""
@export_multiline var initial_goal := "Survive and understand the world."
@export var visual_variant := "alice"

static func defaults(index: int) -> AgentConfig:
	var config := AgentConfig.new()
	var presets := [
		{"id": "alice", "name": "Alice", "variant": "alice", "bio": "Alice values cooperation and enjoys exploring.", "personality": {"sociability": 0.9, "generosity": 0.85, "aggression": 0.1, "curiosity": 0.8, "empathy": 0.9, "selfishness": 0.1, "friendliness": 0.9, "cooperation": 0.9}},
		{"id": "bob", "name": "Bob", "variant": "bob", "bio": "Bob is practical, guarded, and puts his own survival first.", "personality": {"sociability": 0.2, "generosity": 0.15, "aggression": 0.4, "curiosity": 0.5, "empathy": 0.2, "selfishness": 0.8, "friendliness": 0.3, "cooperation": 0.2}},
		{"id": "charlie", "name": "Charlie", "variant": "charlie", "bio": "Charlie is curious, observant, and open to cooperation.", "personality": {"sociability": 0.65, "generosity": 0.55, "aggression": 0.15, "curiosity": 0.9, "empathy": 0.7, "selfishness": 0.35, "friendliness": 0.65, "cooperation": 0.55}},
	]
	var preset: Dictionary = presets[index] if index < presets.size() else {"id": "agent_%s" % (index + 1), "name": "Agent %s" % (index + 1), "variant": ["alice", "bob", "charlie"][index % 3], "bio": "A new inhabitant of this forest.", "personality": {}}
	config.agent_id = str(preset.id)
	config.agent_name = str(preset.name)
	config.visual_variant = str(preset.variant)
	config.background = str(preset.bio)
	config.personality = Dictionary(preset.personality).duplicate(true)
	return config
