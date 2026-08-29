import os

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from ai_provider import decide
from models import AgentIntent, AgentState

load_dotenv()
app = FastAPI(title="AI World Decision Server")

DEFAULT_CORS_ORIGINS = "https://pfalli.github.io,http://localhost:8000,http://localhost:8080"
cors_origins = [origin.strip() for origin in os.getenv("CORS_ORIGINS", DEFAULT_CORS_ORIGINS).split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

@app.post("/decide", response_model=AgentIntent)
def make_decision(state: AgentState) -> AgentIntent:
    try:
        return decide(state)
    except (ValueError, RuntimeError) as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
