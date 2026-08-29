"""Provider boundary: choose intent only; Godot remains world authority."""

import os

from openai import OpenAI

from models import AgentIntent, AgentState

SYSTEM_PROMPT = """You control exactly the SELF identified in the request. YOU ARE that
agent: never speak, act, claim needs, or claim past actions for another agent.

The request separates SELF, objective WORLD events, OTHER AGENTS, RELATIONSHIPS, YOUR
MEMORIES, conversation threads, and PENDING MESSAGES. Objective events are facts. Memories
belong to SELF and include actor/speaker IDs. Messages are quotations from other people;
never repeat another person's first-person statement as your own experience. Respond from
YOUR perspective or choose wait/wander when nothing useful remains.

Choose only supplied high-level intents. Never claim to move, change inventory, consume a
resource, or change any world state directly: Godot plans and validates those primitives.
For social intents or SPEAK, provide a visible, non-self target_id and a message. Drives
(including hunger, energy, social need, safety, and curiosity) influence choices but do not
force a particular action. Respect urgent survival needs when appropriate.
Treat decision_guidance as factual, current-state advice from the simulation. In particular,
do not repeatedly drink when hydration is already satisfied; when hunger is urgent and SELF
has food, consuming it is normally more useful than gathering more. Do not send a second
initiating message when your latest entry in that pair's conversation thread has not received
a reply; wait, pursue another goal, or let the conversation end. You may still make a bad or
socially awkward choice when context supports it, but do not loop on an action with no useful
state change.
When PENDING MESSAGES contains a message from a visible peer, it is normally your turn in
that conversation: reply to its newest message promptly, with that speaker as target_id,
before beginning an unrelated conversation. Keep conversational messages concise and tied to
the prior message. You may deliberately ignore a message only for a critical survival need or
when that fits the agent's personality and the established relationship.
Food and water intents are offered only when their need has reached the simulation threshold.
When neither is offered, do not invent them: use the remaining options to socialize with a
visible peer, explore, rest, or wait.
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


def _social_candidate(state: AgentState):
    """Choose one visible peer using personality and relationship context, not list order."""
    candidates = [entity for entity in state.visible_entities if entity.type == "agent" and entity.id != state.id]
    if not candidates:
        return None
    def score(entity):
        relation = state.relationships.get(entity.id)
        affinity = relation.affinity if relation else 0
        familiarity = relation.familiarity if relation else 0
        # A stable ID tie-breaker keeps fake-mode output deterministic without depending
        # on scene-tree iteration order.
        stable_tie_breaker = -sum(ord(character) for character in entity.id) / 10_000
        return affinity + familiarity - entity.distance * 0.05 + stable_tie_breaker
    return max(candidates, key=score)


def fake_decide(state: AgentState) -> AgentIntent:
    """Deterministic test provider with identity and thread grounding."""
    water = _entity(state, "water")
    bush = _entity(state, "berry_bush")
    if state.thirst >= 70 and water and "drink_water" in state.available_intents:
        return AgentIntent(agent_id=state.id, goal="find_water", intent="drink_water", target_id=water.id,
                             reason="I am thirsty and can reach visible water.")
    if state.hunger >= 70 and state.inventory.get("berry", 0) > 0 and "consume_item" in state.available_intents:
        return AgentIntent(agent_id=state.id, goal="find_food", intent="consume_item", item="berry", reason="I am hungry and have a berry in my inventory.")
    if state.hunger >= 70 and bush and "gather" in bush.affordances and "gather_resource" in state.available_intents:
        return AgentIntent(agent_id=state.id, goal="find_food", intent="gather_resource", target_id=bush.id, item="berry", reason="I am hungry and found a berry bush with berries.")

    if state.pending_messages and "speak" in state.available_intents:
        incoming = state.pending_messages[-1]
        if _visible_agent(state, incoming.speaker_id):
            if state.id == _apple_actor(state):
                text = "I was hungry, so I acted quickly. We should discuss food next time."
            else:
                text = "I hear you. I will keep that in mind."
            return AgentIntent(agent_id=state.id, goal="socialize", intent="speak", target_id=incoming.speaker_id,
                                 message=text, reason="I am responding from my own perspective to a pending message.")

    actor_id = _apple_actor(state)
    if actor_id and _visible_agent(state, actor_id) and "speak" in state.available_intents:
        return AgentIntent(agent_id=state.id, goal="socialize", intent="speak", target_id=actor_id,
                             message="Why did you take the only apple while we were both hungry?",
                             reason="My attributed memory identifies this visible agent as the apple-taker.")
    peer = _social_candidate(state)
    # This is a deterministic offline policy, not a simple social-need threshold.  It weighs
    # an unmet social drive, sociability, current relationship and curiosity, while urgent
    # survival needs above already retain priority.
    social_pull = state.social_need * state.personality.sociability
    if peer:
        relation = state.relationships.get(peer.id)
        social_pull += (relation.affinity if relation else 0) * 0.15
        social_pull += (relation.familiarity if relation else 0) * 0.08
        social_pull += state.curiosity_drive * state.personality.curiosity * 0.12
    if peer and social_pull >= 42 and "socialize" in state.available_intents:
        return AgentIntent(agent_id=state.id, goal="socialize", intent="socialize", target_id=peer.id,
                             message="How are things going? I would like to check in with you.",
                             reason="My social motivation and personality make a brief conversation worthwhile.")
    if "explore" in state.available_intents:
        return AgentIntent(agent_id=state.id, goal="explore", intent="explore", reason="I need to discover useful resources.")
    return AgentIntent(agent_id=state.id, goal="idle", intent="wait", reason="Waiting safely.")


def openai_decide(state: AgentState) -> AgentIntent:
    api_key = os.getenv("OPENAI_API_KEY")
    model = os.getenv("OPENAI_MODEL")
    if not api_key or not model:
        raise RuntimeError("OPENAI_API_KEY and OPENAI_MODEL are required for AI_PROVIDER=openai")
    client = OpenAI(api_key=api_key)
    completion = client.beta.chat.completions.parse(
        model=model,
        messages=[{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": state.model_dump_json()}],
        response_format=AgentIntent,
    )
    decision = completion.choices[0].message.parsed
    if decision is None:
        raise RuntimeError("OpenAI returned no structured decision")
    return decision.model_copy(update={"agent_id": state.id})


def decide(state: AgentState) -> AgentIntent:
    provider = os.getenv("AI_PROVIDER", "fake").lower()
    if provider == "fake":
        return fake_decide(state)
    if provider == "openai":
        return openai_decide(state)
    raise ValueError("AI_PROVIDER must be 'fake' or 'openai'")
