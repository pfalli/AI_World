# AI World — Implement V3 to V6: Social Autonomous Agents

The current AI World prototype is working.

Current architecture:

Godot 4
→ Agent observes world
→ FastAPI
→ AI provider
→ structured decision
→ Godot validates action
→ Godot executes action

Current world:

* Alice
* Bob
* one Apple

Current actions:

* take_apple
* talk
* wander
* wait

Example current event log:

[08:34:03] World ready. Apple is available.
[08:34:09] Bob observes Alice, Apple
[08:34:09] Bob decided TAKE_APPLE
[08:34:09] Bob took Apple.
[08:34:09] Alice observes Bob
[08:34:09] Alice decided TALK
[08:34:09] Alice: Hello Bob. What should we do next?
[08:34:14] Bob observes Alice
[08:34:14] Bob decided TALK
[08:34:14] Bob: Hello Alice. What should we do next?
[08:34:14] Alice observes Bob
[08:34:14] Alice decided TALK
[08:34:14] Alice: Hello Bob. What should we do next?

The fundamental vertical slice works.

The problem is that the agents currently behave mostly statelessly:

* conversations repeat
* agents do not meaningfully remember previous events
* Bob taking the apple has little future consequence
* relationships do not evolve
* conversations are not real multi-turn interactions
* personality has little persistent influence

Implement V3–V6 to turn Alice and Bob into persistent social agents.

IMPORTANT:

Do not build the larger survival world yet.

Do NOT add:

* trees
* crafting
* houses
* animals
* economy
* combat
* jobs
* generations
* PostgreSQL
* vector databases
* embeddings
* RAG
* LangChain
* complex agent frameworks

We will build the world after this milestone.

Keep the architecture simple and understandable.

---

## V3 — MULTIPLE AUTONOMOUS AGENTS

Generalize the existing Alice/Bob implementation so the system supports an arbitrary number of agents.

The world should not contain hardcoded logic such as:

if Alice...
if Bob...

Agents should be instances of the same reusable Agent scene/class.

Each agent should have:

id
name
personality
hunger
energy
position
current_action
current_goal
relationships
memories

Example:

Alice:
{
"id": "alice",
"name": "Alice",
"personality": {
"friendliness": 0.9,
"cooperation": 0.9,
"curiosity": 0.8,
"selfishness": 0.1,
"aggression": 0.1
}
}

Bob:
{
"id": "bob",
"name": "Bob",
"personality": {
"friendliness": 0.3,
"cooperation": 0.2,
"curiosity": 0.5,
"selfishness": 0.8,
"aggression": 0.4
}
}

Use normalized personality values from 0.0 to 1.0.

Do not hardcode behavior based on names.

The system should work if later I add:

Charlie
Diana
Marco
Sofia

without modifying the AI architecture.

For this version Alice and Bob are sufficient for the default scene, but adding another Agent instance should require minimal configuration.

---

## AGENT GOALS

Introduce a simple current_goal field.

Examples:

find_food
socialize
explore
rest
idle

The goal is NOT a complicated planner.

The AI may choose/update a high-level goal when making decisions.

Example structured response:

{
"agent_id": "alice",
"goal": "socialize",
"action": "talk",
"target_id": "bob",
"message": "Bob, why did you take the only apple?",
"reason": "Bob took the only available food while I was hungry."
}

Store current_goal on the agent.

Display it in the UI/debug information.

---

## V4 — REAL AGENT-TO-AGENT CONVERSATION

Replace the current repeated generic TALK behavior with actual contextual conversations.

When Agent A talks to Agent B:

1. Agent A decides to TALK.
2. Agent A produces a message.
3. Godot delivers the message to Agent B.
4. Agent B receives the message as an event/perception.
5. Agent B may respond during its next decision.
6. Both agents remember the conversation.

Example:

Alice:
"Bob, why did you take the only apple?"

Bob receives:

{
"type": "message",
"from": "alice",
"message": "Bob, why did you take the only apple?"
}

Bob may respond:

"I was starving. I saw it first."

Alice later receives that response.

Do NOT create an infinite immediate conversation loop.

Messages should enter the normal agent perception/decision cycle.

An agent may choose:

talk
wander
wait

instead of answering.

The LLM should decide whether responding is appropriate.

---

## CONVERSATION CONTEXT

When asking the LLM to make a decision, include recent relevant conversation.

Example:

Recent conversation with Bob:

Alice: "Why did you take the apple?"
Bob: "I was starving."
Alice: "You could have asked me."

Do not send unlimited conversation history.

Use a configurable limit such as the most recent 5–10 relevant messages/events.

---

## ANTI-REPETITION

Solve the current behavior where agents repeatedly say:

"Hello Bob. What should we do next?"

The prompt should explicitly tell agents:

* avoid repeating the same message
* consider what was already discussed
* do not greet the same nearby person every decision cycle
* TALK only when there is a reason to communicate
* WAIT or WANDER are valid choices
* conversations should react to recent events

Implement a small deterministic repetition guard as well.

For example:

If an agent generates exactly the same message to the same target within a recent time window, reject it or convert the action to WAIT.

Do not rely exclusively on prompting.

---

## V5 — MEMORY

Create persistent short/medium-term memory for each agent.

Do NOT use a vector database.

For now use an in-memory list/array.

Memory object:

{
"id": "...",
"timestamp": "...",
"type": "event",
"description": "Bob took the only apple while Alice was hungry.",
"importance": 8,
"related_agents": ["bob"],
"created_at_tick": 123
}

Possible memory types:

event
conversation
observation
relationship
action

Importance:

1–10

Examples:

Low importance:

"I saw Bob walking nearby."

importance = 2

Medium:

"Bob told me he was hungry."

importance = 5

High:

"Bob took the only apple while I was starving."

importance = 8

For now importance may be assigned using simple deterministic rules.

Do not make another LLM request merely to score every memory.

---

## MEMORY CREATION

Agents should remember meaningful events.

Examples:

Agent sees another agent take scarce food:

"Bob took the only apple."

Agent receives message:

"Bob told me he took the apple because he was starving."

Agent performs action:

"I asked Bob why he took the apple."

Do not store every frame or every trivial observation.

Avoid memory spam.

---

## MEMORY RETRIEVAL

Before requesting an AI decision, select relevant memories.

Keep this simple.

Score memories based on:

* importance
* recency
* whether currently visible agents appear in related_agents

Something conceptually like:

score =
importance_weight

* recency_weight
* relationship_relevance

Send only the top N memories.

For example:

N = 8

Prompt:

Relevant memories:

* Bob took the only apple while I was hungry.
* Bob told me he was starving.
* I previously asked Bob why he did not share.

This gives the agent continuity.

---

## MEMORY LIMIT

Prevent unlimited memory growth.

Use a configurable maximum, for example:

MAX_MEMORIES = 100

When exceeded, remove low-importance old memories first.

Keep implementation simple.

Do not implement semantic embeddings yet.

---

## OPTIONAL SIMPLE REFLECTION

Implement a lightweight reflection mechanism only if it can remain simple.

Do NOT make frequent extra LLM calls.

For example, after several important events, an agent may store a derived memory such as:

"Bob tends to prioritize himself when resources are scarce."

However:

Prefer deterministic relationship updates over expensive reflection calls for V6.

If reflection significantly complicates the architecture, leave a clean extension point and document it instead of implementing it.

---

## V6 — PERSONALITY

Personality must influence decisions.

Use personality traits such as:

friendliness
cooperation
curiosity
selfishness
aggression

Values:

0.0–1.0

Include personality in the AI prompt.

Explain the traits behaviorally.

Example:

High cooperation:
You tend to share resources and seek mutually beneficial solutions.

High selfishness:
You prioritize your own needs when resources are scarce.

High curiosity:
You prefer exploring and interacting with unfamiliar things.

High aggression:
You are more willing to confront others.

Do not tell the model to mechanically obey personality numbers.

Tell it to treat them as behavioral tendencies.

Personality should remain stable during this version.

---

## V6 — RELATIONSHIPS

Each agent should maintain its OWN relationship state toward other agents.

Relationship must NOT automatically be symmetric.

Alice may trust Bob 20/100.

Bob may trust Alice 70/100.

Use:

trust: -100 to +100
affinity: -100 to +100

Optional:

respect: -100 to +100

Start neutral or with configurable initial values.

Example:

Alice → Bob

{
"trust": 0,
"affinity": 10
}

Bob → Alice

{
"trust": 0,
"affinity": 0
}

---

## RELATIONSHIP EVENTS

Update relationships deterministically when meaningful events occur.

Examples:

Agent shares food:

trust +10
affinity +5

Agent takes scarce food while another hungry agent is present:

other agent's trust toward actor -15
affinity -5

Agent gives useful information:

trust +5

Agent insults another:

affinity -10

Agent lies:

Do NOT attempt complex lie detection yet.

Agent repeatedly behaves cooperatively:

trust gradually increases.

Clamp values:

-100 <= relationship <= 100

---

## RELATIONSHIP → AI

Include relationships in AI decision context.

Example:

Relationships:

Bob:
trust: -15
affinity: -5

Relevant memories:

* Bob took the only apple while I was hungry.

Recent conversation:

Bob: "I was starving."

The model should use these naturally when deciding what to do or say.

---

## SOCIAL EVENT SYSTEM

Create a simple event mechanism so world events can be observed by relevant agents.

Example event:

{
"type": "resource_taken",
"actor_id": "bob",
"target_id": "apple_1",
"description": "Bob took Apple.",
"position": {...}
}

Nearby agents can receive the event.

This allows Alice to know:

Bob took Apple.

rather than merely discovering later that:

Apple no longer exists.

Events should support future world development.

Potential future events:

resource_taken
resource_given
message
agent_arrived
agent_left
attack
death
construction
discovery

Do NOT implement all of these.

Design the event structure so they can be added later.

For this version implement only what current actions need.

---

## AGENT DECISION INPUT

By V6, the AI backend should receive something conceptually like:

{
"id": "alice",
"name": "Alice",

```
"needs": {
    "hunger": 80,
    "energy": 90
},

"personality": {
    "friendliness": 0.9,
    "cooperation": 0.9,
    "curiosity": 0.8,
    "selfishness": 0.1,
    "aggression": 0.1
},

"current_goal": "find_food",

"visible_entities": [
    {
        "type": "agent",
        "id": "bob",
        "name": "Bob"
    }
],

"relationships": {
    "bob": {
        "trust": -15,
        "affinity": -5
    }
},

"recent_events": [
    "Bob took Apple."
],

"relevant_memories": [
    {
        "description": "Bob took the only apple while I was hungry.",
        "importance": 8
    }
],

"recent_messages": [
    {
        "from": "bob",
        "message": "I was starving."
    }
],

"available_actions": [
    "talk",
    "wander",
    "wait"
]
```

}

Do not necessarily copy this exact schema if the current architecture already has a cleaner compatible structure.

Preserve working code where possible.

---

## AGENT DECISION OUTPUT

Use structured output.

Example:

{
"agent_id": "alice",
"goal": "socialize",
"action": "talk",
"target_id": "bob",
"message": "I understand you were hungry, but taking the only food without discussing it makes it difficult for me to trust you.",
"reason": "Bob took the scarce food and my trust in him has decreased."
}

Possible actions remain:

take_apple
talk
wander
wait

Do NOT expand world actions yet.

---

## FAKE PROVIDER MUST STILL WORK

Maintain AI_PROVIDER=fake.

Update fake behavior enough to exercise:

* memory
* conversations
* relationships
* anti-repetition

Fake mode does not need sophisticated human behavior.

Its purpose is integration testing.

OpenAI mode should produce the interesting behavior.

---

## OBSERVABILITY / UI

Improve the debug UI enough that I can inspect what is happening.

When clicking/selecting an agent, or through a simple panel, show:

Name

Current goal

Current action

Hunger

Energy

Personality

Relationships

Recent memories

Recent messages

AI reason

Example:

ALICE

Goal:
Socialize

Action:
Talk to Bob

Hunger:
80

Personality:
Friendly: 0.9
Cooperative: 0.9
Selfish: 0.1

Relationship with Bob:
Trust: -15
Affinity: -5

Relevant memories:

* Bob took the only apple.
* Bob said he was starving.

Last AI reasoning:
"I want to confront Bob about taking the food."

Keep the UI functional and simple.

Do not spend significant effort on visual design.

---

## EVENT LOG

Improve the world log.

Example desired behavior:

[08:40:01] World ready.
[08:40:06] Bob observes Alice and Apple.
[08:40:06] Bob decided TAKE_APPLE.
[08:40:07] Bob took Apple.
[08:40:07] Alice observed: Bob took Apple.
[08:40:07] Alice memory created: "Bob took the only apple."
[08:40:07] Alice → Bob trust: 0 → -15
[08:40:11] Alice decided TALK.
[08:40:11] Alice → Bob: "Why did you take the only apple?"
[08:40:16] Bob remembered Alice's question.
[08:40:16] Bob decided TALK.
[08:40:16] Bob → Alice: "I was starving. I saw it first."
[08:40:21] Alice decided WANDER.

The important improvement is:

DO NOT produce:

Hello Bob.
Hello Alice.
Hello Bob.
Hello Alice.

forever.

---

## IMPORTANT: AI REASONING PRIVACY / DEBUGGING

Do not request hidden chain-of-thought from the model.

The `reason` field should be a short decision explanation only.

Example:

"Bob took the scarce food, so Alice wants to confront him."

Do not ask the model to reveal detailed internal reasoning.

---

## TOKEN / COST CONTROL

Keep AI calls efficient.

Do NOT send:

* complete world state
* every historical memory
* every previous conversation
* huge system prompts on every possible game mechanic

Send only information relevant to that agent.

Target:

roughly 5–10 relevant memories/events/messages maximum.

Maintain configurable decision interval.

Do not query every frame.

---

## PERSISTENCE

For V6:

Memory and relationships only need to persist while the simulation is running.

If the existing project already has simple save/load functionality, it is acceptable to extend it.

Otherwise DO NOT introduce a database.

Long-term persistence comes later.

---

## TEST SCENARIO

Keep the one-apple scenario specifically because it is a useful social experiment.

Alice:

friendly = 0.9
cooperation = 0.9
curiosity = 0.8
selfishness = 0.1
aggression = 0.1

Bob:

friendly = 0.3
cooperation = 0.2
curiosity = 0.5
selfishness = 0.8
aggression = 0.4

Both hungry.

One apple.

Run the simulation.

We want to observe whether:

1. One agent takes the apple.
2. The other observes the event.
3. A memory is created.
4. Relationship values change.
5. Future decisions receive that memory.
6. Conversation references what actually happened.
7. The conversation does not endlessly repeat.
8. Agents eventually choose other actions.

---

## SECOND TEST SCENARIO

Make it easy to spawn a third agent:

Charlie

Do not necessarily enable Charlie in the default world.

But verify the architecture does not assume exactly two agents.

Charlie should be able to:

* perceive Alice/Bob
* maintain separate relationships
* remember events
* talk
* make independent decisions

---

## ARCHITECTURAL PRINCIPLE

Maintain strict separation:

# WORLD TRUTH

Godot

# AGENT SUBJECTIVE STATE

memories + relationships + personality

# DECISION

AI backend

# EXECUTION

Godot

Example:

Bob believes:
"Maybe Alice has food."

This does NOT create food.

Only Godot world state determines whether food exists.

Similarly, memories can be incomplete or subjective.

World state remains authoritative.

---

## DO NOT BUILD WORLD V7 YET

Stop after completing V6.

Do not add:

forest
trees
water
rocks
animals
tools
crafting
buildings
weather
day/night
combat
farming
skills
knowledge
economy

Those will be the next development phase.

---

## BEFORE FINISHING

Run/test as much as the environment allows.

Verify:

* Python syntax
* FastAPI health endpoint
* fake provider decisions
* structured schemas
* Godot scripts if Godot is available
* no obvious null-reference errors
* no hardcoded Alice/Bob assumptions
* AI failure falls back safely
* repeated messages are prevented
* relationship values remain within bounds
* memory limit works

Do not delete working functionality from the existing V1 implementation unnecessarily.

Refactor incrementally.

---

AFTER IMPLEMENTATION

Give me:

1. Short explanation of what changed from the previous version.
2. Updated project tree.
3. Important files/classes and their responsibilities.
4. Exact Windows commands to run the backend.
5. How to switch between fake and OpenAI.
6. How memory works.
7. How relationship updates work.
8. How conversations work.
9. How to add Charlie.
10. What I should manually test in Godot.
11. Known limitations.
12. STOP THERE. Do not implement world/survival features yet.
