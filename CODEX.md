# V7.2 — Fix Duplicate Action Completion

V7.1 is much better. Resource approach, gathering, eating, drinking, and urgent-need threshold handling now work.

However, the latest simulation log reveals one major bug:

`action completed` is emitted repeatedly, sometimes dozens of times per second for the same action, especially during/after EXPLORE.

Example:

Alice action completed
Alice action completed
Alice action completed
Alice action completed
...

Fix ONLY this lifecycle/state-machine problem. Do not add new gameplay features.

## Required behavior

Every action instance must transition only once:

IDLE
→ EXECUTING / APPROACHING_TARGET
→ COMPLETED or FAILED
→ IDLE

`complete_action()` must be idempotent: calling it again for an already completed/idle action must do nothing.

After an action completes:

* clear its target/destination as appropriate
* clear/reset the current action
* update the state
* emit `ACTION_COMPLETE` exactly once
* request at most one new AI decision

Especially inspect EXPLORE/WANDER movement logic. A condition such as `distance_to_destination <= threshold` must not call `complete_action()` every physics frame after arrival.

Add a unique action ID/counter if useful for debugging:

`Alice ACTION #12 EXPLORE started`
`Alice ACTION #12 completed`

There must never be:

`ACTION #12 completed`
`ACTION #12 completed`

Also preserve the existing AI-request debounce protection.

## Important

Do NOT change:

* LLM prompts
* personalities
* needs
* resource logic
* perception
* memory
* relationships
* affordances
* survival balancing

Do not implement V8.

## Test

Run agents with repeated EXPLORE actions and verify:

EXPLORE starts
→ agent moves
→ destination reached
→ ACTION_COMPLETE exactly once
→ one AI_REQUEST
→ next action starts

Also verify GATHER, DRINK, EAT, TALK, GIVE, REST, WAIT and WANDER cannot emit duplicate completion events.

At the end, explain the root cause, files changed, and how the lifecycle now prevents duplicate completion.
