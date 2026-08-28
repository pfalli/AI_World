"""Provider boundary: providers choose intent; Godot remains world authority."""

import os
from openai import OpenAI
from models import AgentDecision, AgentState

SYSTEM_PROMPT = """You control one person in a small simulated world. Return only the validated decision schema. Choose only supplied actions and never claim to change world state. Personality values are behavioural tendencies, not rigid rules: cooperation and friendliness favour constructive social choices; selfishness prioritizes personal needs; curiosity favours exploration; aggression permits confrontation. Use the agent's own relationships, recent events, memories, and messages naturally. TALK only with a reason, react to actual recent context, and avoid repeating greetings or messages. WAIT and WANDER are valid choices. Keep reason a brief decision explanation, not hidden reasoning."""

def _entity(state: AgentState, entity_type: str):
    return next((item for item in state.visible_entities if item.type == entity_type), None)

def _message_from(state: AgentState):
    return state.recent_messages[-1] if state.recent_messages else None

def fake_decide(state: AgentState) -> AgentDecision:
    """Deterministic offline behaviour that exercises social state without greeting loops."""
    apple = _entity(state, "food")
    other_agent = _entity(state, "agent")
    incoming = _message_from(state)
    if state.hunger > 70 and apple and "take_apple" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="find_food", action="take_apple", target_id=apple.id, reason="I am hungry and the visible apple is scarce food.")
    if incoming and incoming.from_id != state.id and "talk" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="socialize", action="talk", target_id=incoming.from_id, message="I was hungry, so I acted quickly. We should discuss food next time.", reason="I am responding to a recent message instead of repeating a greeting.")
    if other_agent and any("took Apple" in event for event in state.recent_events) and "talk" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="socialize", action="talk", target_id=other_agent.id, message="Why did you take the only apple while we were both hungry?", reason="The recent scarce-food event affects this relationship.")
    if "wander" in state.available_actions:
        return AgentDecision(agent_id=state.id, goal="explore", action="wander", reason="There is no urgent social or food action.")
    return AgentDecision(agent_id=state.id, goal="idle", action="wait", reason="Waiting safely.")

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
