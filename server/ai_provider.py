"""Small provider boundary: providers choose intent, never change game state."""

import os
from openai import OpenAI
from models import AgentDecision, AgentState

SYSTEM_PROMPT = """You control one person in a simulated world. Choose only from supplied available actions. You cannot change world state directly, invent objects, or invent actions. The game engine determines whether an action succeeds. Choose based on personality, needs, and current observations."""

def _entity(state: AgentState, entity_type: str):
    return next((item for item in state.visible_entities if item.type == entity_type), None)

def fake_decide(state: AgentState) -> AgentDecision:
    """Deterministic offline behaviour for exercising the full HTTP pipeline."""
    apple = _entity(state, "food")
    other_agent = _entity(state, "agent")
    if state.hunger > 70 and apple and "take_apple" in state.available_actions:
        return AgentDecision(agent_id=state.id, action="take_apple", target_id=apple.id, reason="I am hungry and food is visible.")
    if other_agent and "talk" in state.available_actions:
        return AgentDecision(agent_id=state.id, action="talk", target_id=other_agent.id, message=f"Hello {other_agent.name}. What should we do next?", reason="Another person is visible, so I will talk.")
    if "wander" in state.available_actions:
        return AgentDecision(agent_id=state.id, action="wander", reason="I will explore the nearby area.")
    return AgentDecision(agent_id=state.id, action="wait", reason="Waiting safely.")

def openai_decide(state: AgentState) -> AgentDecision:
    """Uses the official SDK structured-output helper to produce a validated decision."""
    api_key = os.getenv("OPENAI_API_KEY")
    model = os.getenv("OPENAI_MODEL")
    if not api_key or not model:
        raise RuntimeError("OPENAI_API_KEY and OPENAI_MODEL are required for AI_PROVIDER=openai")
    client = OpenAI(api_key=api_key)
    completion = client.beta.chat.completions.parse(model=model, messages=[{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": state.model_dump_json()}], response_format=AgentDecision)
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
