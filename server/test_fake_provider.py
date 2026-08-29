"""Focused deterministic tests for V6.5 identity and perspective grounding."""

import unittest

from ai_provider import fake_decide
from models import AgentState


def state_for(agent_id: str, memories: list[dict], pending: list[dict] | None = None) -> AgentState:
    return AgentState.model_validate({
        "id": agent_id,
        "name": agent_id.title(),
        "hunger": 40,
        "thirst": 30,
        "energy": 90,
        "personality": {"friendliness": .5, "cooperation": .5, "curiosity": .5, "selfishness": .5, "aggression": .2, "sociability": .3, "generosity": .5, "empathy": .5},
        "social_need": 20,
        "safety": 100,
        "curiosity_drive": 50,
        "current_goal": "idle",
        "position": {"x": 0, "y": 0},
        "visible_entities": [{"type": "agent", "id": "alice", "name": "Alice"}, {"type": "agent", "id": "bob", "name": "Bob"}],
        "relevant_memories": memories,
        "pending_messages": pending or [],
        "available_intents": ["speak", "explore", "wait"],
    })


class FakeProviderGroundingTests(unittest.TestCase):
    def test_apple_memory_targets_the_recorded_actor(self) -> None:
        charlie = state_for("charlie", [{"id": "m1", "type": "observed_action", "actor_id": "bob", "target_id": "apple_1", "observer_id": "charlie", "description": "Bob took an apple.", "importance": 8, "tick": 1}])
        self.assertEqual(fake_decide(charlie).target_id, "bob")

    def test_receiver_does_not_repeat_speaker_first_person_statement(self) -> None:
        alice = state_for("alice", [], [{"speaker_id": "bob", "target_id": "alice", "text": "I was hungry, so I acted quickly.", "tick": 2, "pending": True}])
        decision = fake_decide(alice)
        self.assertEqual(decision.target_id, "bob")
        self.assertNotEqual(decision.message, "I was hungry, so I acted quickly.")

    def test_no_pending_context_ends_with_non_talk_action(self) -> None:
        alice = state_for("alice", [])
        self.assertEqual(fake_decide(alice).intent, "explore")

    def test_social_personality_can_initiate_a_contextual_conversation(self) -> None:
        alice = state_for("alice", [])
        alice.social_need = 70
        alice.personality.sociability = .9
        decision = fake_decide(alice)
        self.assertEqual(decision.intent, "socialize")
        self.assertEqual(decision.target_id, "bob")

    def test_reserved_personality_keeps_exploring_with_the_same_social_need(self) -> None:
        bob = state_for("bob", [])
        bob.social_need = 70
        bob.personality.sociability = .1
        self.assertEqual(fake_decide(bob).intent, "explore")


if __name__ == "__main__":
    unittest.main()
