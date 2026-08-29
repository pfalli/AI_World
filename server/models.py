"""Schemas for bounded, identity-grounded agent decisions."""

from typing import Literal

from pydantic import BaseModel, Field

GoalName = Literal["find_food", "find_water", "rest", "explore", "socialize", "help_agent", "idle"]
IntentName = Literal["gather_resource", "drink_water", "consume_item", "speak", "give_item", "explore", "rest", "wait", "socialize", "request_help", "offer_help", "confront", "avoid"]


class Position(BaseModel):
    x: float
    y: float


class VisibleEntity(BaseModel):
    type: str
    id: str
    name: str
    distance: float = 0
    affordances: list[str] = Field(default_factory=list)


class Personality(BaseModel):
    friendliness: float = Field(ge=0.0, le=1.0)
    cooperation: float = Field(ge=0.0, le=1.0)
    curiosity: float = Field(ge=0.0, le=1.0)
    selfishness: float = Field(ge=0.0, le=1.0)
    aggression: float = Field(ge=0.0, le=1.0)
    sociability: float = Field(ge=0.0, le=1.0)
    generosity: float = Field(ge=0.0, le=1.0)
    empathy: float = Field(ge=0.0, le=1.0)


class Relationship(BaseModel):
    trust: int = Field(ge=-100, le=100)
    affinity: int = Field(ge=-100, le=100)
    anger: int = Field(default=0, ge=0, le=100)
    familiarity: int = Field(default=0, ge=0, le=100)


class WorldEvent(BaseModel):
    event_id: str
    type: str
    actor_id: str
    target_id: str | None = None
    resource_type: str | None = None
    tick: int


class Memory(BaseModel):
    id: str
    type: str
    actor_id: str | None = None
    target_id: str | None = None
    observer_id: str
    speaker_id: str | None = None
    listener_id: str | None = None
    message: str | None = None
    description: str = Field(min_length=1, max_length=500)
    importance: int = Field(ge=1, le=10)
    tick: int


class ConversationMessage(BaseModel):
    speaker_id: str
    target_id: str
    text: str = Field(min_length=1, max_length=500)
    tick: int


class PendingMessage(ConversationMessage):
    pending: bool = True


class AgentState(BaseModel):
    id: str
    name: str
    hunger: int = Field(ge=0, le=100)
    thirst: int = Field(ge=0, le=100)
    energy: int = Field(ge=0, le=100)
    social_need: int = Field(ge=0, le=100)
    safety: int = Field(ge=0, le=100)
    curiosity_drive: int = Field(ge=0, le=100)
    personality: Personality
    current_goal: GoalName = "idle"
    position: Position
    visible_entities: list[VisibleEntity]
    inventory: dict[str, int] = Field(default_factory=dict)
    known_locations: list[dict] = Field(default_factory=list, max_length=8)
    relationships: dict[str, Relationship] = Field(default_factory=dict)
    recent_events: list[WorldEvent] = Field(default_factory=list, max_length=8)
    relevant_memories: list[Memory] = Field(default_factory=list, max_length=8)
    conversation_threads: dict[str, list[ConversationMessage]] = Field(default_factory=dict)
    pending_messages: list[PendingMessage] = Field(default_factory=list, max_length=6)
    decision_guidance: list[str] = Field(default_factory=list, max_length=6)
    available_intents: list[IntentName]


class AgentIntent(BaseModel):
    agent_id: str
    goal: GoalName = "idle"
    intent: IntentName
    target_id: str | None = None
    item: str | None = Field(default=None, max_length=100)
    quantity: int = Field(default=1, ge=1, le=99)
    message: str | None = Field(default=None, max_length=500)
    reason: str = Field(min_length=1, max_length=500)
