from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from ai_provider import decide
from models import AgentDecision, AgentState

load_dotenv()
app = FastAPI(title="AI World Decision Server")

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

@app.post("/decide", response_model=AgentDecision)
def make_decision(state: AgentState) -> AgentDecision:
    try:
        return decide(state)
    except (ValueError, RuntimeError) as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
