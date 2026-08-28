"""Schemas for the bounded, per-agent decision request."""

from typing import Literal

from pydantic import BaseModel, Field

ActionName = Literal["take_apple", "talk", "wander", "wait"]
GoalName = Literal["find_food", "socialize", "explore", "rest", "idle"]


class Position(BaseModel):
    x: float
    y: float


class VisibleEntity(BaseModel):
    type: str
    id: str
    name: str


class Personality(BaseModel):
    friendliness: float = Field(ge=0.0, le=1.0)
    cooperation: float = Field(ge=0.0, le=1.0)
    curiosity: float = Field(ge=0.0, le=1.0)
    selfishness: float = Field(ge=0.0, le=1.0)
    aggression: float = Field(ge=0.0, le=1.0)


class Relationship(BaseModel):
    trust: int = Field(ge=-100, le=100)
    affinity: int = Field(ge=-100, le=100)


class Memory(BaseModel):
    description: str = Field(min_length=1, max_length=500)
    importance: int = Field(ge=1, le=10)


class RecentMessage(BaseModel):
    from_id: str
    from_name: str
    message: str = Field(min_length=1, max_length=500)


class AgentState(BaseModel):
    id: str
    name: str
    hunger: int = Field(ge=0, le=100)
    energy: int = Field(ge=0, le=100)
    personality: Personality
    current_goal: GoalName = "idle"
    position: Position
    visible_entities: list[VisibleEntity]
    relationships: dict[str, Relationship] = Field(default_factory=dict)
    recent_events: list[str] = Field(default_factory=list, max_length=10)
    relevant_memories: list[Memory] = Field(default_factory=list, max_length=8)
    recent_messages: list[RecentMessage] = Field(default_factory=list, max_length=10)
    available_actions: list[ActionName]


class AgentDecision(BaseModel):
    agent_id: str
    goal: GoalName = "idle"
    action: ActionName
    target_id: str | None = None
    message: str | None = Field(default=None, max_length=500)
    reason: str = Field(min_length=1, max_length=500)
