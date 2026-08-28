"""Request and response schemas shared by the decision endpoint."""

from typing import Literal

from pydantic import BaseModel, Field

ActionName = Literal["take_apple", "talk", "wander", "wait"]

class Position(BaseModel):
    x: float
    y: float

class VisibleEntity(BaseModel):
    type: str
    id: str
    name: str

class AgentState(BaseModel):
    id: str
    name: str
    hunger: int = Field(ge=0, le=100)
    energy: int = Field(ge=0, le=100)
    personality: list[str]
    position: Position
    visible_entities: list[VisibleEntity]
    available_actions: list[ActionName]

class AgentDecision(BaseModel):
    agent_id: str
    action: ActionName
    target_id: str | None = None
    message: str | None = None
    reason: str
