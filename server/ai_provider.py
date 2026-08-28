"""Provider boundary: choose intent only; Godot remains world authority."""

import os

from openai import OpenAI

from models import AgentDecision, AgentState

SYSTEM_PROMPT = """You control exactly the SELF identified in the request. YOU ARE that
agent: never speak, act, claim needs, or claim past actions for another agent.

The request separates SELF, objective WORLD events, OTHER AGENTS, RELATIONSHIPS, YOUR
MEMORIES, conversation threads, and PENDING MESSAGES. Objective events are facts. Memories
belong to SELF and include actor/speaker IDs. Messages are quotations from other people;
never repeat another person's first-person statement as your own experience. Respond from
YOUR perspective or choose wait/wander when nothing useful remains.

Choose only supplied actions. For TALK, provide a visible, non-self target_id and a message.
If a message refers to an action another agent performed, target that responsible agent unless
there is a clear contextual reason not to. Respect conversation threads: do not mix messages
between different pairs. Personality numbers are tendencies, not rules. Avoid repeated or
near-immediate messages. Return a short reason, never hidden chain-of-thought."""


def _entity(state: AgentState, entity_type: str):
    return next((item for item in state.visible_entities if item.type == entity_type), None)


def _visible_agent(state: AgentState, agent_id: str):
    return next((item for item in state.visible_entities if item.type == "agent" and item.id == agent_id), None)


def _apple_actor(state: AgentState) -> str | None:
    for memory in state.relevant_memories:
        if memory.target_id == "apple_1" and memory.actor_id and memory.type in {"observed_action", "performed_action"}:
            return memory.actor_id
    return None


def fake_decide(state: AgentState) -> AgentDecision:
    """Deterministic test provider with identity and thread grounding."""
    water = _entity(state, "water")
    bush = _entity(state, "berry_bush")
    if state.thirst >= 70 and water and "drink" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="find_water", action="drink", target_id=water.id,
                             reason="I am thirsty and can reach visible water.")
    if state.hunger >= 70 and state.inventory.get("berry", 0) > 0 and "eat" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="find_food", action="eat", parameters={"item": "berry", "quantity": 1}, reason="I am hungry and have a berry in my inventory.")
    if state.hunger >= 70 and bush and "gather" in bush.affordances and "gather" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="find_food", action="gather", target_id=bush.id, reason="I am hungry and found a berry bush with berries.")

    if state.pending_messages and "talk" in state.available_actions:
        incoming = state.pending_messages[-1]
        if _visible_agent(state, incoming.speaker_id):
            if state.id == _apple_actor(state):
                text = "I was hungry, so I acted quickly. We should discuss food next time."
            else:
                text = "I hear you. I will keep that in mind."
            return AgentDecision(agent_id=state.id, goal="socialize", action="talk", target_id=incoming.speaker_id,
                                 message=text, reason="I am responding from my own perspective to a pending message.")

    actor_id = _apple_actor(state)
    if actor_id and _visible_agent(state, actor_id) and "talk" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="socialize", action="talk", target_id=actor_id,
                             message="Why did you take the only apple while we were both hungry?",
                             reason="My attributed memory identifies this visible agent as the apple-taker.")
    if "explore" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="explore", action="explore", reason="I need to discover useful resources.")
    return AgentDecision(agent_id=state.id, goal="idle", action="wait", reason="Waiting safely.")


def openai_decide(state: AgentState) -> AgentDecision:
    api_key = os.getenv("OPENAI_API_KEY")
    model = os.getenv("OPENAI_MODEL")
    if not api_key or not model:
        raise RuntimeError("OPENAI_API_KEY and OPENAI_MODEL are required for AI_PROVIDER=openai")
    client = OpenAI(api_key=api_key)
    completion = client.beta.chat.completions.parse(
        model=model,
        messages=[{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": state.model_dump_json()}],
        response_format=AgentDecision,
    )
    decision = completion.choices[0].message.parsed
    if decision is None:
        raise RuntimeError("OpenAI returned no structured decision")
    return decision.model_copy(update={"agent_id": state.id})


def decide(state: AgentState) -> AgentDecision:
    provider = os.getenv("AI_PROVIDER", "fake").lower()
    if provider == "fake":
        return fake_decide(state)
    if provider == "openai":
        return openai_decide(state)
    raise ValueError("AI_PROVIDER must be 'fake' or 'openai'")
