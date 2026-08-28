# AI World — Architecture History

This file records major implementation milestones. Add a dated entry whenever the project gains a meaningful architectural capability.

## 2026-08-28 — V1: Authoritative world / AI decision vertical slice

Built the initial playable prototype:

- Godot 4 is the authoritative world and action executor.
- FastAPI exposes `POST /decide` and `GET /health`.
- The server supports a deterministic `fake` provider and an OpenAI provider.
- Godot sends a bounded observation, receives a structured decision, validates it, and safely executes `take_apple`, `talk`, `wander`, or `wait`.
- Default scenario: Alice, Bob, and one apple.
- AI/network failure falls back to `wait`, leaving the simulation responsive.

Architecture:

```text
Godot world truth → FastAPI → AI provider → structured intent → Godot validation/execution
```

## 2026-08-28 — V3–V6: Persistent social autonomous agents

Generalized agents into reusable `WorldAgent` instances. The architecture no longer contains decision logic based on Alice or Bob's names.

### Agent subjective state

Each agent now keeps its own:

- unique ID, name, position, needs, current action, and current goal;
- normalized personality traits: friendliness, cooperation, curiosity, selfishness, and aggression;
- directional relationships (`trust` and `affinity`) toward other agents;
- recent events, received messages, action/conversation memories, and a short decision explanation.

### Bounded AI context and decisions

- Decision input now includes goal, personality, visible entities, relationships, recent events, relevant memories, and recent messages.
- Decision output now includes a validated high-level goal as well as action, target, message, and a short non-chain-of-thought reason.
- The OpenAI prompt instructs agents to treat personality as tendencies, react to real context, avoid generic greetings, and use `wait`/`wander` when appropriate.
- Fake mode now exercises the apple conflict, contextual messaging, and non-repeating behavior for offline integration tests.

### Memory

- Memories are in-memory only for the duration of a simulation.
- Meaningful resource, conversation, and action events create deterministic memories with importance 1–10.
- Memory is capped at 100 items per agent; when full, the oldest low-importance memory is removed first.
- At most eight memories are selected for each decision, scored using importance, recency, and relevance to visible agents.

### Social events, conversations, and relationships

- Added extensible social events. Current event types are `resource_taken` and `message`.
- Taking the apple emits a nearby-observable event; nearby hungry agents remember it.
- A hungry observer deterministically changes its own relationship toward the apple-taker by trust −15 and affinity −5. Relationships are clamped to −100…100 and are not automatically symmetric.
- A talk action creates a message event for its target. The recipient receives it as normal context for a future decision—there is no immediate reply loop.
- A deterministic guard converts an exact repeated message to the same target within 30 logical decision ticks into `wait`.

### Observability and default world

- Added an agent inspector panel: click an agent to see goal, action, needs, personality, relationships, memories, messages, and last AI reason.
- Added Charlie to the default scene as a third independent `WorldAgent` instance. He participates without any architecture changes.

## 2026-08-28 — V6.5: Cognition correctness refactor

- World events are now objective, structured facts with IDs, actor/target IDs, type, position, and logical tick.
- Observers create their own attributed memories from those facts; memory records include observer, actor, target, speaker/listener, message, importance, and tick where applicable.
- Decision context is identity-grounded: it separates self, visible world entities, relationships, memories, per-pair conversation threads, and pending incoming messages.
- Added six-message conversation threads keyed by the two participant IDs.
- Added pending-message processing, per-target talk cooldowns, normalized duplicate prevention, and strict Godot target validation (visible, reachable, non-self agent).
- Replaced fixed frequent decisions with triggers: initial/action completion, important event, direct message, urgent need, or decision timeout.
- Updated fake-provider behaviour to target the `actor_id` recorded in apple memories, rather than the first visible agent.
- Added deterministic backend tests for actor-target grounding, quoted first-person message handling, and conversation termination into `wander`.

## 2026-08-28 — V7: Minimal survival world

- Added a configurable survival-world foundation with distance-limited perception, trees, rocks, berry bushes, and water.
- Added generic actions for gathering berries, eating, drinking, resting, exploration, resource giving, and navigation to an agent's own known location.
- Added authoritative inventory, thirst, resource depletion, needs updates, resource affordances, and private known-resource locations.
- Updated the decision schema and fake provider with survival priorities: drink, eat, gather, then explore.

## 2026-08-28 — Simulation logs

- Each Godot run now recreates `logs/simulation.log` for readable event output and `logs/simulation.jsonl` for one JSON object per log event.
- Log records include a timestamp and simulation tick; files are flushed after every event and closed when the scene exits.

## 2026-08-28 — V7.1: Survival execution loop

- Added an action state machine (`IDLE`, `APPROACHING_TARGET`, `EXECUTING`, `COMPLETED`, `FAILED`) that commits agents to an interaction while they physically approach its target.
- Gather, drink, give, and talk now approach valid distant targets automatically before executing; no movement instructions are sent to the AI.
- Added explicit action-failure reasons including `TOO_FAR`, `RESOURCE_EMPTY`, `TARGET_MISSING`, `INVALID_TARGET`, `OUT_OF_INVENTORY`, and `NAVIGATION_FAILED`.
- Replaced continuous urgent-need checks with threshold-crossing triggers and re-arm hysteresis after recovery.
- Added AI request counters and approach/arrival/completion logs for simulation debugging.

## 2026-08-28 — V7.2: Action lifecycle correctness

- Added unique per-agent action IDs and idempotent completion/failure transitions.
- Completing or failing an action now clears its active ID, destination, pending intent, movement velocity, and current action before emitting exactly one lifecycle log.
- Movement arrival cannot re-complete an explore/wander action on subsequent physics frames; long-running rest/talk actions are completed once before their next decision starts.

## Deliberately deferred

The project still intentionally excludes survival-world features and persistence infrastructure: crafting, economy, combat, animals, buildings, databases, embeddings, vector search, RAG, planners, and long-term save/load.
