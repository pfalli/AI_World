# AI World V7 — Survival World, Perception, Affordances & Generic Actions

The project currently has a working V6.5 autonomous social-agent architecture.

Current features include:

* Godot 4 2D world
* Python/FastAPI AI backend
* OpenAI + fake AI providers
* multiple autonomous agents
* structured AI decisions
* personalities
* relationships
* subjective memories
* structured world events
* agent-to-agent conversations
* conversation threads
* decision triggers
* action/goal commitment
* anti-repetition
* world-authoritative action validation

Now implement V7.

The objective of V7 is NOT to create a complicated survival game.

The objective is to give the autonomous agents a simple physical world in which they must:

* explore
* discover resources
* become hungry/thirsty/tired
* find food
* find water
* gather resources
* consume resources
* remember locations
* optionally help other agents
* make decisions using only what they personally know

The world must remain authoritative.

The LLM decides INTENT.

Godot decides PHYSICAL REALITY.

---

# CORE DESIGN PRINCIPLE

Maintain this architecture:

WORLD TRUTH
↓
PERCEPTION
↓
SUBJECTIVE KNOWLEDGE
↓
GOAL
↓
AI DECISION
↓
GENERIC ACTION
↓
GODOT VALIDATION
↓
EXECUTION
↓
ACTION RESULT
↓
EVENT / MEMORY
↓
NEXT DECISION

Do NOT give the LLM direct control over game state.

Do NOT give agents omniscient knowledge of the map.

---

# 1. CREATE A SIMPLE FOREST WORLD

Replace/expand the empty test room with a larger 2D map.

Do NOT spend significant time on graphics.

Simple colored shapes, generated visuals, labels, or existing simple project assets are sufficient.

The map should contain:

* open ground
* trees
* berry bushes
* water sources
* rocks
* Alice
* Bob
* Charlie

Conceptually:

🌲      🌲             🫐

```
   Alice

                🌲
```

```WATER ~~~~~~~~~

               Bob

     🪨                    🌲

              🫐

                         Charlie

🌲        🌲

The world should be significantly larger than the visible screen so exploration matters.

Use a camera system if necessary.

Do not implement procedural world generation yet.

A manually/configurably populated map is sufficient.

---

# 2. RESOURCE TYPES

Implement four basic environment entities.

## Tree

Properties:

id
type = "tree"
position

For V7 trees are mostly environmental objects.

Affordances may be empty or include inspect.

DO NOT implement cutting trees yet.

---

## BerryBush

Properties:

id
type = "berry_bush"
position
berries_available
max_berries

Example:

berries_available = 5

Affordances:

gather

When an agent gathers:

berries_available decreases

Agent inventory receives berries.

When empty:

gather should no longer be available.

OPTIONAL:

Simple berry regeneration after a configurable long interval is acceptable.

If implemented, keep it deterministic and configurable.

---

## WaterSource

Properties:

id
type = "water"
position

Affordances:

drink

Water does not need to deplete in V7.

---

## Rock

Properties:

id
type = "rock"
position

For V7 rocks are environmental objects.

Do NOT implement mining yet.

---

# 3. INVENTORY

Give each agent a simple inventory.

Do not build a complex RPG inventory UI.

A dictionary/map is enough.

Example:

{
    "berry": 3
}

Support at minimum:

berry

Create clean methods such as:

add_item()
remove_item()
has_item()
get_item_count()

Inventory belongs to the authoritative Godot world.

The LLM cannot invent inventory items.

---

# 4. NEEDS

Agents currently have hunger and energy.

Add/standardize:

hunger
thirst
energy

Use a consistent scale.

Recommended:

0 = fully satisfied
100 = critical need

Example:

hunger:
0 → full
100 → starving

thirst:
0 → hydrated
100 → severely thirsty

energy:
100 → fully rested
0 → exhausted

If changing existing energy semantics would create unnecessary regressions, preserve the current semantics but document them clearly.

Needs should change gradually over simulated time.

Example configurable rates:

hunger increases slowly
thirst increases somewhat faster
energy decreases slowly while active

Do NOT tie these directly to frame rate.

Use simulation time/ticks.

Keep rates configurable.

---

# 5. NEED THRESHOLDS

Define useful thresholds.

Example:

HUNGER:

0–39:
normal

40–69:
hungry

70–89:
very hungry

90–100:
critical

THIRST:

same concept

ENERGY:

100–61:
normal

60–31:
tired

30–11:
very tired

10–0:
critical

These thresholds should help trigger decisions.

Do not hardcode them across many files.

Centralize/configure them.

---

# 6. GENERIC ACTION SYSTEM

Refactor the current special-purpose actions toward generic actions.

V7 should support:

wander
explore
gather
eat
drink
give
talk
rest
wait

Remove or deprecate `take_apple` as a special world-specific action.

The single Apple test may remain as a regression/test scene if useful, but the main survival world should not depend on `take_apple`.

The AI decision structure should look conceptually like:

{
    "agent_id": "alice",
    "goal": "find_food",
    "action": "gather",
    "target_id": "berry_bush_4",
    "parameters": {},
    "message": null,
    "reason": "I am hungry and I found berries."
}

Not every action requires target_id.

Examples:

wander:
target_id = null

rest:
target_id = null

eat:
target_id may be an inventory item/type

talk:
target_id = another agent

give:
target_id = another agent
parameters = {
    "item": "berry",
    "quantity": 1
}

---

# 7. AFFORDANCE SYSTEM

Do NOT maintain one huge global list of actions that are always possible.

World entities should expose AFFORDANCES.

An affordance means:

"What can this agent potentially do with this object?"

Examples:

BerryBush:
gather

WaterSource:
drink

Agent:
talk
give

Tree:
inspect, if inspect exists

Rock:
inspect, if inspect exists

The agent's perception should include available interactions.

Example:

{
    "id": "berry_bush_4",
    "type": "berry_bush",
    "distance": 42,
    "position_relative": {
        "x": 20,
        "y": -15
    },
    "affordances": [
        "gather"
    ]
}

Water:

{
    "id": "water_1",
    "type": "water",
    "distance": 120,
    "affordances": [
        "drink"
    ]
}

Bob:

{
    "id": "bob",
    "type": "agent",
    "distance": 30,
    "affordances": [
        "talk",
        "give"
    ]
}

Affordances describe possible interactions.

Godot STILL validates whether an attempted action succeeds.

---

# 8. PERCEPTION RADIUS

Agents must NOT see the entire world.

Give agents a configurable perception radius.

Example:

PERCEPTION_RADIUS = 250 pixels

Only entities within perception range should be included in visible_entities.

Do not implement complicated vision cones or raycasting yet.

Distance-based perception is sufficient.

This means:

Alice may see:

tree_4
berry_bush_2

Bob may see:

water_1
rock_7

Charlie may see:

nothing useful

Each agent has different information.

This is essential.

---

# 9. NO GLOBAL MAP KNOWLEDGE

The AI backend must NOT receive:

- complete resource list
- all berry bushes
- all water sources
- complete map
- positions of unseen agents
- positions of unseen resources

Only send:

current perception
personal memories
personal known locations
current needs
inventory
relationships
messages
current goal

Godot knows everything.

Agents do not.

---

# 10. KNOWN LOCATIONS

Add simple personal location memory.

When an agent perceives an important resource, remember it.

Example:

Alice discovers:

berry_bush_4 at world position (700, 300)

Alice knowledge:

known_locations = {
    "berry_bush_4": {
        "type": "berry_bush",
        "last_known_position": [700, 300],
        "last_seen_tick": 400
    }
}

Bob does NOT automatically receive this information.

Known locations are agent-specific.

Store at minimum:

entity_id
entity_type
last_known_position
last_seen_tick

Do NOT implement a knowledge graph.

---

# 11. STALE KNOWLEDGE

Known locations are memories, not world truth.

Example:

Alice remembers:

berry_bush_4 has berries.

Later Bob gathers all berries.

Alice may still believe berries exist there until she returns and observes the empty bush.

This is GOOD.

Do not automatically synchronize agent knowledge with world truth.

When Alice revisits the bush:

WORLD:
berries = 0

Alice observes this and updates her knowledge.

This distinction is important for future emergent behavior.

---

# 12. EXPLORE ACTION

Implement `explore` differently from `wander`.

WANDER:

casual/random nearby movement.

EXPLORE:

move toward an area the agent has not recently visited.

Keep this simple.

Possible implementation:

Divide map into coarse exploration cells/grid regions.

Each agent tracks visited regions.

Explore selects a nearby low-visited/unvisited region.

Do NOT use the LLM to generate coordinates.

The AI chooses:

{
    "action": "explore"
}

Godot chooses an appropriate unexplored destination.

This allows agents to discover resources naturally.

---

# 13. MOVEMENT

Use Godot navigation or the existing movement implementation.

The LLM must NOT produce:

move north
move north
move east
move east

The LLM chooses:

explore
wander
go toward known resource if supported

Godot handles:

destination
path
movement
collision

If navigation meshes/maps significantly complicate the current simple world, use a simpler movement implementation.

Do not overengineer navigation.

---

# 14. GATHER

Example AI decision:

{
    "action": "gather",
    "target_id": "berry_bush_4"
}

Godot validates:

target exists
target is BerryBush
target has gather affordance
target is within interaction distance
berries_available > 0

If too far away:

either:

A. move toward target and then execute

OR

B. return action failure requiring movement

Prefer whichever fits the existing action architecture cleanly.

Do not teleport agents.

On success:

berry_bush berries_available -= 1

agent inventory berry += 1

Emit event:

{
    "type": "resource_gathered",
    "actor_id": "alice",
    "target_id": "berry_bush_4",
    "item": "berry",
    "quantity": 1
}

---

# 15. EAT

Agent may eat berries from inventory.

Decision:

{
    "action": "eat",
    "parameters": {
        "item": "berry",
        "quantity": 1
    }
}

Godot validates inventory.

On success:

remove berry
reduce hunger

Example:

hunger = max(0, hunger - 25)

Values should be configurable.

Emit action result/event.

---

# 16. DRINK

Agent may drink from a visible/reachable WaterSource.

Decision:

{
    "action": "drink",
    "target_id": "water_1"
}

Godot validates target and distance.

On success:

reduce thirst substantially.

Example:

thirst = max(0, thirst - 50)

Water does not deplete in V7.

---

# 17. REST

Implement simple REST.

Agent stops moving for a period.

Energy gradually increases.

Rest can be interrupted by:

important event
direct message
critical need

Do NOT implement beds/shelters yet.

---

# 18. GIVE

Implement resource sharing.

Example:

Alice has:

berry = 3

Alice sees Bob.

AI:

{
    "action": "give",
    "target_id": "bob",
    "parameters": {
        "item": "berry",
        "quantity": 1
    }
}

Godot validates:

Alice has item
Bob exists
Bob is close enough
quantity valid

On success:

Alice berry -1
Bob berry +1

Emit:

resource_given

Relationship effects:

Receiver trust/affinity toward giver should increase modestly.

Example:

trust +5
affinity +3

Keep configurable.

This action is particularly important for social experiments.

---

# 19. ACTION RESULTS

Every meaningful action should produce a structured result.

Example success:

{
    "success": true,
    "action": "gather",
    "target_id": "berry_bush_4",
    "result": "berry_collected"
}

Failure:

{
    "success": false,
    "action": "gather",
    "target_id": "berry_bush_4",
    "reason": "resource_empty"
}

Agents should be able to remember important failures.

Example:

"I returned to the berry bush, but it was empty."

Do not create high-importance memory for every trivial movement failure.

---

# 20. GOALS

Support simple survival goals.

Examples:

find_food
find_water
rest
explore
socialize
help_agent
idle

The AI may choose/update goals.

Needs should strongly influence reasonable goals.

Example:

hunger = 95

The prompt should make clear that severe hunger is urgent.

But do NOT deterministically force the AI to always choose food.

Personality and context may influence decisions.

---

# 21. KNOWN RESOURCE NAVIGATION

If an agent remembers a resource location, the AI may choose to seek it.

Avoid requiring the LLM to output raw coordinates.

Preferred decision:

{
    "goal": "find_food",
    "action": "go_to_known",
    "target_id": "berry_bush_4"
}

If necessary add:

go_to_known

as a navigation action.

Godot resolves the remembered target location from the agent's subjective known_locations.

IMPORTANT:

Use the AGENT'S remembered location.

Do not secretly use current world position if the agent has stale knowledge.

This preserves subjective knowledge.

---

# 22. COMMUNICATION ABOUT RESOURCES

Do not implement a formal knowledge-transfer system yet.

However, normal TALK should allow agents to mention discovered resources.

Example:

Alice:
"I found berries north of here."

Bob may remember that statement as a conversation memory.

Do NOT automatically insert Alice's exact berry location into Bob's known_locations simply because she said it.

For V7, Bob can remember the claim in natural-language memory.

Formal knowledge transfer can come later.

---

# 23. DECISION CONTEXT

The AI should receive concise context.

Conceptually:

SELF

Alice

Needs:
Hunger: 78
Thirst: 35
Energy: 70

Inventory:
Berry: 0

Personality:
...

Goal:
find_food

---

CURRENT PERCEPTION

berry_bush_4
distance: 50
affordances: gather

Bob
distance: 80
affordances: talk, give

---

KNOWN LOCATIONS

water_1
last seen 40 ticks ago
remembered direction/distance or location abstraction

berry_bush_2
last seen 100 ticks ago

---

RELEVANT MEMORIES

- Bob took scarce food earlier.
- I found water near the southern area.

---

RELATIONSHIPS

Bob:
trust: -15
affinity: -5

---

AVAILABLE HIGH-LEVEL ACTIONS

gather
eat
drink
give
talk
explore
wander
rest
wait
go_to_known

Keep prompts concise.

Do not send all memories or all known locations.

Select relevant/recent ones.

---

# 24. DECISION TRIGGERS

Preserve V6.5 event-driven decisions.

Do NOT return to querying AI every 5 seconds unconditionally.

Request a new AI decision when appropriate:

current action completes
important resource discovered
resource becomes unavailable
direct message received
hunger threshold crossed
thirst threshold crossed
energy threshold crossed
action fails
goal completes
maximum decision timeout reached

Log trigger reason.

Example:

Alice decision requested: HUNGER_THRESHOLD

Bob decision requested: RESOURCE_DISCOVERED

Charlie decision requested: ACTION_COMPLETE

---

# 25. RESOURCE DISCOVERY

When an agent sees a resource for the first time:

create/update known location

optionally create a memory

Example:

Alice discovered BerryBush.

Memory:

"I found a berry bush."

Importance should depend on current needs.

If Alice is starving:

importance high.

If Alice is full:

importance lower.

Use deterministic rules where possible.

Do NOT call another LLM for scoring.

---

# 26. SIMPLE WORLD CONFIGURATION

Make world parameters easy to change.

Prefer a centralized configuration/resource/constants file for things such as:

perception radius
interaction distance
hunger rate
thirst rate
energy rate
berry nutrition
water hydration
berry bush capacity
berry regeneration
rest recovery
decision timeout
map bounds

Avoid scattering magic numbers across scripts.

---

# 27. DEBUG / OBSERVABILITY UI

Update the agent inspection panel.

When selecting an agent show:

Name

Current goal

Current action

Hunger
Thirst
Energy

Inventory

Personality

Relationships

Visible entities

Known locations

Recent memories

Pending messages

Last AI decision reason

Example:

ALICE

Goal:
Find Food

Action:
Explore

Hunger:
82

Thirst:
34

Energy:
71

Inventory:
Berry x0

Visible:
Tree
Bob

Known Locations:
BerryBush #4 — last seen tick 300
Water #1 — last seen tick 180

Relationship:
Bob
Trust: -15

Memory:
"Bob took scarce food."
"I found water south of here."

---

# 28. WORLD EVENT LOG

Produce useful logs.

Example:

[10:01:00] Alice decision requested: ACTION_COMPLETE
[10:01:01] Alice decided EXPLORE (find_food)
[10:01:08] Alice discovered BerryBush berry_bush_4
[10:01:08] Alice memory created: I found a berry bush.
[10:01:08] Alice decision requested: RESOURCE_DISCOVERED
[10:01:09] Alice decided GATHER target=berry_bush_4
[10:01:11] Alice gathered 1 Berry.
[10:01:11] Alice inventory Berry: 0 → 1
[10:01:12] Alice decided EAT.
[10:01:12] Alice ate Berry.
[10:01:12] Alice hunger: 82 → 57

Meanwhile:

[10:01:05] Bob discovered WaterSource water_1
[10:01:06] Bob drank water.
[10:01:06] Bob thirst: 72 → 22

This log is extremely important for evaluating emergent behavior.

---

# 29. FAKE PROVIDER

Update fake AI provider so the survival world can be tested without OpenAI.

Example deterministic priorities:

critical thirst + visible water:
drink

critical hunger + berry inventory:
eat

critical hunger + visible berry bush:
gather

critical thirst + known water:
go_to_known

critical hunger + known berry bush:
go_to_known

otherwise:
explore

Occasionally allow talk/give for testing.

The fake provider is for integration testing, not realistic behavior.

---

# 30. OPENAI PROVIDER

Preserve the current OpenAI integration.

Use structured output.

The model must only select actions supplied by the system.

It must never invent:

resources
items
locations
agents
actions

Prompt should explicitly state:

You only know what appears in your perception, memories, known locations, conversations, and current state.

You do NOT know the complete world.

Do not assume unseen resources exist.

You may explore to discover new things.

---

# 31. SURVIVAL CONSEQUENCES

For V7 do NOT implement death yet unless the current architecture makes it trivial.

At critical hunger/thirst/energy:

log clearly that the agent is in critical condition.

Example:

Alice is critically thirsty.

Death will be introduced later.

The purpose of V7 is behavior testing, not population simulation yet.

---

# 32. DO NOT IMPLEMENT YET

Do NOT add:

tree cutting
wood
mining
stone inventory
tools
axes
crafting
buildings
shelters
fire
cooking
hunting
animals
combat
farming
weather
seasons
day/night
disease
death
reproduction
children
generations
economy
currency
jobs
government
factions
formal knowledge transfer
technology tree
skill learning
PostgreSQL
vector database
embeddings
RAG
LangChain
procedural generation

Those belong to later versions.

---

# 33. TEST SCENARIO

Create a default survival test world.

Agents:

Alice
Bob
Charlie

Use their existing personalities and relationships.

Place them relatively close together initially.

Place resources so agents must explore.

For example:

START AREA

Alice
Bob
Charlie

No immediately visible food/water for everyone.

Elsewhere:

2–4 berry bushes

1–2 water sources

several trees

several rocks

Make at least some resources outside initial perception radius.

The expected behavior is:

Agents start with needs.

↓
They explore.

↓
Different agents discover different resources.

↓
Their personal known_locations diverge.

↓
Hungry agents seek berries.

↓
Thirsty agents seek water.

↓
Agents gather/eat/drink.

↓
Agents may talk.

↓
Agents may share berries depending on AI/personality.

This is the first real survival experiment.

---

# 34. IMPORTANT TEST: NO OMNISCIENCE

Explicitly test:

Alice has discovered berry_bush_1.

Bob has NOT discovered berry_bush_1.

Verify:

Alice AI context contains berry_bush_1.

Bob AI context DOES NOT contain berry_bush_1.

Bob must discover it himself or learn about it socially in a future system.

This is a critical requirement.

---

# 35. IMPORTANT TEST: STALE KNOWLEDGE

Test:

Alice discovers berry_bush_1.

Alice leaves.

Bob empties berry_bush_1.

Alice still remembers its last known location.

Alice returns expecting berries.

Alice observes:

berries_available = 0

Alice updates her knowledge/memory.

This behavior is desirable.

Agents' beliefs do not automatically synchronize with world truth.

---

# 36. IMPORTANT TEST: RESOURCE SHARING

Test:

Alice has 3 berries.

Bob has 0 berries and is hungry.

Alice sees Bob.

Verify that the AI is technically capable of choosing:

{
    "action": "give",
    "target_id": "bob",
    "parameters": {
        "item": "berry",
        "quantity": 1
    }
}

Godot validates and transfers the item.

Bob's relationship toward Alice improves.

Do NOT force Alice to share.

Her AI/personality should determine whether she does.

---

# 37. CODE QUALITY

Keep this implementation understandable.

Prefer components/classes around concepts such as:

Agent
World
WorldEntity
BerryBush
WaterSource
Inventory
Needs
Perception
KnownLocation
ActionExecutor
WorldEvent

But adapt to the existing architecture rather than performing a huge rewrite.

Avoid giant classes.

Avoid premature generic frameworks.

Comment important architecture decisions.

---

# SUCCESS CRITERIA

V7 is successful when:

1. Alice, Bob, and Charlie live in a larger world.

2. Hunger, thirst, and energy change over simulation time.

3. Agents only perceive nearby entities.

4. Agents do NOT know the complete map.

5. Agents can explore.

6. Different agents discover different resources.

7. Resource discoveries become personal known locations.

8. Agents can gather berries.

9. Berries enter inventory.

10. Agents can eat berries.

11. Eating reduces hunger.

12. Agents can find/drink water.

13. Drinking reduces thirst.

14. Agents can rest.

15. Agents can give berries to another agent.

16. Giving physically transfers inventory.

17. Relationships react to sharing.

18. Agents can remember resource locations.

19. Knowledge may become stale.

20. World remains authoritative.

21. LLM outputs generic high-level actions rather than movement commands.

22. AI calls are event-driven rather than frame-driven.

23. Fake provider still works.

24. OpenAI provider still works.

25. The debug UI lets me inspect individual agent knowledge.

---

# AFTER IMPLEMENTATION

Do NOT immediately implement V8.

Instead provide:

1. Updated project architecture.
2. New files/classes.
3. Explanation of the affordance system.
4. Explanation of perception.
5. Explanation of known locations.
6. Explanation of stale knowledge.
7. Explanation of inventory.
8. Explanation of survival needs.
9. Explanation of generic actions.
10. Explanation of how EXPLORE works.
11. Explanation of how GIVE works.
12. Exact Windows commands to run.
13. How to test with fake AI.
14. How to test with OpenAI.
15. A suggested 5–10 minute manual simulation test.
16. Known limitations.
17. STOP. Do not implement V8.
```
