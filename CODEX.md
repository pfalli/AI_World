# V7.1 — Fix the Survival Simulation Loop

V7 is implemented, but the simulation log revealed a broken execution loop.

Current problem:

Agents correctly discover resources and decide things such as:

* GATHER berry_bush_1
* DRINK water_1

However, if the resource is too far away, the action fails. The agent then immediately requests another AI decision because of URGENT_NEED and repeats the same failed action many times per second.

Example:

URGENT_NEED
→ GATHER berry_bush_1
→ too far
→ URGENT_NEED
→ GATHER berry_bush_1
→ too far
→ repeat forever

Fix this WITHOUT adding new gameplay features.

## 1. Approach before interaction

High-level AI actions such as:

* gather
* drink
* give
* talk

must automatically approach their target when necessary.

Example:

AI decides:

GATHER berry_bush_1

Godot should execute:

GATHER intent
→ target too far
→ APPROACHING_TARGET
→ walk toward target
→ enter interaction distance
→ GATHER
→ action complete

The LLM must NOT control individual movement steps.

Do not teleport agents.

## 2. Add action states

Implement a simple deterministic state machine such as:

IDLE
APPROACHING_TARGET
EXECUTING
COMPLETED
FAILED

While APPROACHING_TARGET, do NOT repeatedly request AI decisions.

The agent is committed to the current intent until:

* action succeeds
* target becomes invalid
* navigation fails
* important interruption occurs

## 3. Fix URGENT_NEED spam

URGENT_NEED must trigger when a need CROSSES a threshold, not continuously while it remains above it.

Wrong:

hunger >= 70 → AI request every update

Correct:

69 → 70
→ HUNGER_URGENT triggered once

Use state/threshold flags and hysteresis where useful.

It may trigger again only after the need recovers sufficiently and later becomes urgent again.

## 4. Structured action failures

Replace ambiguous errors like:

"unavailable or too far"

with explicit reasons:

TOO_FAR
RESOURCE_EMPTY
TARGET_MISSING
INVALID_TARGET
OUT_OF_INVENTORY
NAVIGATION_FAILED

Handle deterministic failures without unnecessary AI calls.

Example:

TOO_FAR
→ approach automatically

RESOURCE_EMPTY
→ update agent knowledge
→ current action fails
→ request new decision

## 5. Prevent unnecessary AI calls

AI decisions should occur primarily when:

* action completes
* meaningful action fails
* important event occurs
* direct message arrives
* need threshold is crossed
* decision timeout occurs

Do NOT query AI continuously while an action is executing.

## 6. Improve logging

Add logs that let us understand the execution:

Alice decision GATHER target=berry_bush_1
Alice target distance=180
Alice state=APPROACHING_TARGET
Alice arrived at berry_bush_1
Alice state=EXECUTING
Alice gathered 1 berry
Alice action completed

For water:

Bob decision DRINK target=water_1
Bob approaching water_1
Bob arrived at water_1
Bob drank water
Bob thirst 78 → 28

Also number AI requests:

Alice AI_REQUEST #1 reason=HUNGER_URGENT

This lets us measure API usage.

## Success criteria

After the fix, the simulation should behave like:

Agent discovers resource
→ AI chooses interaction
→ agent physically walks there
→ interaction executes
→ world changes
→ action completes
→ next AI decision

NOT:

discover
→ interact from distance
→ fail
→ retry
→ fail
→ retry

Test specifically:

1. Alice discovers distant berries, walks there, gathers and can eat.
2. Bob discovers distant water, walks there and drinks.
3. URGENT_NEED does not fire continuously.
4. No repeated AI calls while approaching a target.
5. Empty resources cause reconsideration instead of infinite retries.
6. Existing V7 perception, memory, relationships, inventory, affordances and subjective knowledge continue working.

Do NOT implement V8 or new gameplay features.

After implementation, tell me what caused the loop, which files changed, and what I should test manually.
