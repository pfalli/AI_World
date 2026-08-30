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

## 2026-08-28 — Intent → Plan → Primitive Validation foundation

- Replaced direct LLM action output with bounded high-level intents (`gather_resource`, `drink_water`, `consume_item`, `speak`, `give_item`, `explore`, `rest`, and `wait`).
- Added an `IntentPlanner` that maps intents into a small primitive set: `MOVE_TO`, `PICK_UP`, `DROP`, `USE`, `CONSUME`, `SPEAK`, and `WAIT`.
- Added deterministic world validation for primitive targets, interaction range, resource availability, required inventory, valid recipients, and non-empty speech.
- Godot remains the only authority that moves agents or changes resources, inventory, needs, and relationships.
- Invalid primitives are rejected before execution and are recorded as high-importance agent failure observations, triggering a subsequent replan.
- Added structured `[INTENT]`, `[PLAN]`, `[ACTION]`, `[VALIDATION]`, `[RESULT]`, and `[OBSERVATION]` simulation logs.
- Added a headless Godot test covering planning, validated execution preconditions, rejected validation, and useful failure feedback.
- Fixed an inventory-only `CONSUME` validation bug that incorrectly required a world target and caused rapid failed-intent retries; consumption now validates only that the item exists in inventory.

## Deliberately deferred

The project still intentionally excludes survival-world features and persistence infrastructure: crafting, economy, combat, animals, buildings, databases, embeddings, vector search, RAG, planners, and long-term save/load.

## 2026-08-28 — Autonomous social behavior and consequences

- Diagnosed the exploration-only simulation loop: the offline provider had no social motivation path without a pending message or an old apple event, so agents repeatedly explored despite nearby peers.
- Added continuous social, safety, and curiosity drives to agent decision context. Hunger, thirst, and energy retain priority; the deterministic offline provider now weighs social need, sociability, relationship context, and curiosity rather than using a single forced-talk threshold.
- Made Alice, Bob, and Charlie persistently distinct: Alice is highly social, generous, and empathetic; Bob is reserved, selfish, and less empathetic; Charlie is curious, moderately social, and cooperative.
- Extended high-level social intents (`socialize`, request/offer help, confront, avoid) while retaining the existing Intent → Plan → Primitive → Validation architecture. Social intents compile to normal `MOVE_TO` + `SPEAK`; gifts remain validated `DROP` primitives.
- Added social need relief/cooldowns, six-turn conversation sessions, inactivity termination, duplicate-message protection, and delayed session restart so agents neither loop greetings nor become permanently unable to speak again.
- Expanded relationship state with deterministic `trust`, `affinity`, `anger`, and `familiarity`. Successful messages and gifts create participant-owned memories and relationship changes; observers only receive events inside normal perception range.
- Added structured `[NEED]`, `[SOCIAL]`, `[MEMORY]`, and `[RELATIONSHIP]` logs alongside the existing intent/plan/action/validation logs.
- Added headless Godot tests for gift validation and conversation turn/inactivity termination. The existing provider tests now cover personality-dependent social initiation and a reserved agent choosing exploration with the same social need.

## 2026-08-28 — OpenAI-run social execution corrections

- Diagnosed a real simulation run where the local service returned the deterministic fake-provider greeting even though an OpenAI key and model were configured. The local, ignored `server/.env` now explicitly sets `AI_PROVIDER=openai`; no credential was copied or committed.
- Fixed moving-agent interaction approaches: `MOVE_TO` for an agent now tracks that target's live simulation position and finishes inside interaction range, preventing an agent from reaching a stale position and failing a following `SPEAK` as too far away.
- Temporary conversation cooldown/session unavailability now defers the next decision instead of creating a high-importance failure memory and immediate retry storm.

## 2026-08-28 — OpenAI decision-context refinement

- Analysed the first confirmed OpenAI simulation run. Movement-target tracking worked, but the model repeatedly drank while hydrated, kept gathering while carrying berries, and initiated follow-up messages before a peer could answer.
- Added small, factual `decision_guidance` to the bounded agent context. It calls out satisfied thirst, carried food during urgent hunger, critical survival needs, and unanswered outgoing messages. The LLM still chooses its own intent; the simulation remains authoritative.
- Strengthened the model instruction to use that context and avoid no-effect repeats while preserving room for contextual mistakes and non-cooperative social choices.

## 2026-08-28 — Fixed observer UI

- Locked the observer camera to the real forest map: pan and zoom controls were removed, so the player cannot move the map away from the simulation.
- Kept the bottom-left event log visible at all times.
- Added short-lived, world-space speech bubbles above an agent whenever it successfully speaks.
- Added an × button to the selected-agent inspector, which clears selection and closes the panel.

## 2026-08-28 — Simulation-loop resilience

- Analysed an OpenAI run that exposed three loops: agents physically blocked one another at a shared bush, an empty bush caused immediate gather/replan failures, and `WAIT` actions completed fast enough to create excessive decision requests.
- Disabled agent-to-agent physics collision because interaction range and explicit world validation, rather than physical blocking, govern their simulation interactions.
- Made available intents truthful to the agent's currently actionable known or visible resources and inventory. An empty resource is forgotten after validation, remembered as an observation, and defers the next decision instead of causing a rapid retry storm.
- Changed the `WAIT` primitive to defer until the normal decision interval instead of immediately completing into another API request.
- Added deterministic berry regrowth using the existing `max_berries` state, restoring one berry per bush at a configured logical-tick interval so the small survival world remains playable after an initial harvest.

## 2026-08-28 — Need-threshold behavior

- Analysed a run where Bob repeatedly returned to water below a meaningful thirst level and agents kept prioritizing berries rather than normal social or exploratory behavior.
- Added explicit food and water action thresholds at 50. Below their threshold, the corresponding gather, consume, or drink intent is neither offered to the model nor accepted by Godot if returned anyway.
- Added context guidance that directs comfortable agents toward visible peers, exploration, rest, or waiting; giving remains available whenever an agent has food, regardless of its own hunger.

## 2026-08-29 — Conversation turn-flow correction

- Analysed the current OpenAI simulation log: five delivered messages were accompanied by seven deferred speech attempts. A conversation could reach its six-message cap before the recipient was permitted to answer, and pending messages were discarded after any decision, including `wait`.
- A received message now remains pending while an agent moves to reply and is resolved only after a successful `SPEAK` to that sender. A non-social decision remains an explicit choice to leave messages unanswered, preventing request loops while retaining autonomous behaviour.
- Direct replies are permitted across a just-closed session boundary so the last speaker is not stranded. That single closing reply is still logged and remembered but does not request yet another response, preserving the session cap. Sessions now allow eight short turns and use a longer inactivity window (90 logical ticks), reducing artificial cut-offs without changing movement, needs, or resource behaviour.
- Updated the provider instruction to prioritize concise, on-topic replies to visible pending speakers except in critical survival situations.

## 2026-08-30 — V8 application shell and simulation inspection

- Added the application flow: landing menu, world configuration, inhabitant creator, real initialization state, and an observer-oriented simulation HUD.
- Added `ExperimentConfig` and `AgentConfig` resources. Setup values now configure the instantiated forest world's real agent IDs, names, personality dictionaries, biographies, goals, visual variants, initial food amount, and simulation speed.
- Added pause/resume, 1×/2×/4×/16× controls, a live agent inspector, normal-mode meaningful event feed, full filtered world-history panel, and a separate raw developer-log view.
- World history records resource use, social messages, relationship changes, discoveries, failed actions, and world initialization from the existing simulation execution paths.

## 2026-08-30 — Inhabitant creator layout refinement

- Rebuilt the inhabitant creator for the fixed 960×640 application viewport: a persistent Alice/Bob/Charlie selector strip now sits above a vertically scrollable editor, with compact Back and Start World controls kept visible in the footer.
- Agent selection saves the current form before switching, so every configured name, personality value, biography, and goal remains editable without content being clipped or hidden below the screen.
- Replaced the vertically stacked personality inputs with six compact, two-column slider cards. Each card shows the trait, a plain-language tendency description, a slider, and its live numeric value for quick comparison and adjustment.

## 2026-08-30 — Simulation screen hierarchy refinement

- Reworked the simulation header into a two-row information table containing application identity, world name, world time, live simulation counts, status, and controls.
- Framed the forest as a distinct clickable observation viewport beneath the header while retaining the existing event feed, inspector, history, and developer views.

## 2026-08-30 — Dedicated simulation viewport

- Moved the running Godot world into a real `SubViewportContainer` below the application header. The forest is now a bounded render surface, not a full-screen scene hidden behind UI panels.
- The top status table and right-side event/inspector panels occupy separate application regions, so they no longer overlap the visible world.
- Enlarged the forest viewport to 700×500 pixels and narrowed the separate side tools accordingly, giving the autonomous world substantially more visual space without reintroducing UI overlap.
