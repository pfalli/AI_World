# AI World

A minimal 2D artificial-life prototype. Godot owns the world and executes actions; FastAPI asks either a deterministic fake provider or OpenAI for high-level agent intent.

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

The key remains only on the server. The model receives an observation and returns a schema-constrained high-level `AgentDecision`.

## Run the game

1. Start the FastAPI server above.
2. In Godot 4, import/open `game/project.godot`.
3. Press **F6** or the Play button.
4. Watch Alice and Bob's labels and the event panel. They decide approximately every five seconds.

The server address defaults to `http://127.0.0.1:8000` and can be changed on the `World` node in the Inspector.

## Manual checks

- In fake mode, both hungry agents see Apple. The first valid request received and executed takes it; the apple vanishes and that agent's hunger drops by 50.
- After Apple is gone, agents choose `talk` when another agent is visible and show a message.
- Stop the server: the game remains responsive and agents safely fall back to **Waiting**.
- Unsupported actions are converted to `wait` by Godot.

## Troubleshooting

- **Connection errors / Waiting:** start `uvicorn main:app --reload` from `server` and confirm port 8000 is free.
- **Port 8000 already used:** stop the other process or run Uvicorn on another port, then update the World node's `server_url`.
- **Missing API key:** use `AI_PROVIDER=fake`, or set `OPENAI_API_KEY` in `server/.env` for OpenAI mode.
- **Invalid model:** set `OPENAI_MODEL` to a model in your OpenAI account that supports structured outputs.
- **HTTP failures:** the event panel includes the error. The game deliberately falls back to `wait` rather than freezing.

V1 deliberately excludes memory, databases, combat, economy, procedural generation, and other future-world features.
