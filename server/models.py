"""Schemas for bounded, identity-grounded agent decisions."""

from typing import Literal

from pydantic import BaseModel, Field

ActionName = Literal["wander", "explore", "gather", "eat", "drink", "give", "talk", "rest", "wait", "go_to_known"]
GoalName = Literal["find_food", "find_water", "rest", "explore", "socialize", "help_agent", "idle"]


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


class Relationship(BaseModel):
    trust: int = Field(ge=-100, le=100)
    affinity: int = Field(ge=-100, le=100)


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
    available_actions: list[ActionName]


class AgentDecision(BaseModel):
    agent_id: str
    goal: GoalName = "idle"
    action: ActionName
    target_id: str | None = None
    parameters: dict[str, str | int] = Field(default_factory=dict)
    message: str | None = Field(default=None, max_length=500)
    reason: str = Field(min_length=1, max_length=500)
