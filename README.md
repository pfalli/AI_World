# AI World

A small 2D artificial-life prototype with persistent social agents. Godot owns world truth and execution; FastAPI asks either a deterministic fake provider or OpenAI for a bounded high-level intent.

`Godot -> FastAPI -> AI provider -> decision -> Godot`

## Requirements

- Godot 4.x
- Python 3.10+

## Server setup

```powershell
cd server
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn main:app --reload
```

The example configuration uses the local deterministic provider:

```env
AI_PROVIDER=fake
```

Verify it in another PowerShell window:

```powershell
curl http://127.0.0.1:8000/health
```

## OpenAI mode

Edit `server/.env` (never commit it):

```env
AI_PROVIDER=openai
OPENAI_API_KEY=your_key_here
OPENAI_MODEL=gpt-4o-mini
```

The key remains only on the server. The model receives only that agent's bounded context and returns a schema-constrained high-level `AgentDecision`.

## Run the game

1. Start the FastAPI server above.
2. In Godot 4, import/open `game/project.godot`.
3. Press **F6** or the Play button.
4. Watch Alice and Bob's labels and the event panel. Click an agent to inspect its goal, personality, relationships, memories, messages, and last decision reason.

The server address defaults to `http://127.0.0.1:8000` and can be changed on the `World` node in the Inspector.

## Manual checks

- In fake mode, both hungry agents see Apple. The first valid request takes it; nearby agents receive a `resource_taken` event, store a memory, and (when hungry) lose trust and affinity toward the actor.
- The other agent can ask about the apple. The message is delivered as a normal later perception; the recipient may respond on its next decision rather than in an immediate loop.
- Exact repeated messages to the same target are converted to `wait` for 30 simulation ticks.
- Stop the server: the game remains responsive and agents safely fall back to **Waiting**.
- Unsupported actions are converted to `wait` by Godot.

## Troubleshooting

- **Connection errors / Waiting:** start `uvicorn main:app --reload` from `server` and confirm port 8000 is free.
- **Port 8000 already used:** stop the other process or run Uvicorn on another port, then update the World node's `server_url`.
- **Missing API key:** use `AI_PROVIDER=fake`, or set `OPENAI_API_KEY` in `server/.env` for OpenAI mode.
- **Invalid model:** set `OPENAI_MODEL` to a model in your OpenAI account that supports structured outputs.
- **HTTP failures:** the event panel includes the error. The game deliberately falls back to `wait` rather than freezing.

## Social-agent architecture (V3–V6)

Every agent is an instance of `WorldAgent`; no decision logic depends on Alice or Bob's names. Each has normalized (0.0–1.0) personality traits, needs, a current goal, independent directional relationships, recent events/messages, and an in-memory memory list. Memories are capped at 100 per agent; when full, the oldest lowest-importance item is removed. Before each decision, Godot selects at most eight memories using importance, recency, and visible-agent relevance.

World events use a small extensible dictionary (`type`, actor, target, description, position). The current implementation emits `resource_taken` and `message`. Taking the scarce apple creates a high-importance observation for nearby agents and, if they are hungry, deterministically applies trust −15 and affinity −5 toward the taker. Relationship values are clamped to −100…100 and are intentionally not symmetric.

To add Charlie, instance `res://scenes/agent.tscn` as a child of `World/Agents`, assign a unique `agent_id`, name, colour, and five-trait personality dictionary like Alice's. No server or world architecture change is required.

## Known limits

Memory and relationships are intentionally in-memory only and reset when the simulation stops. Event visibility is radius-based, the fake provider is deterministic rather than human-like, and the world still has only the one apple and the original four actions. There is no survival-world content, database, embedding, or planner.

## References
https://github.com/a16z-infra/ai-town

https://github.com/he-yufeng/CoreCoder

## Assets / Credits

- **Seasons of Forest — Free Sample** by **InkBubi**, source: [itch.io](https://inkbubi.itch.io/seasons-of-forest-tileset), licensed **CC0 1.0**. Its supplied `license.txt` remains in `game/assets/seasons_of_forest_free_v1/`.
- **Top-Down Tileset + Animated Character Pack** (`game/assets/AssetPack/AssetPack`): used for the animated character sheets. This copy contains no README, author, source URL, or license file, so no license is asserted here; confirm its provenance before redistributing the project.
