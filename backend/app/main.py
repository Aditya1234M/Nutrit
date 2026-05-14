"""NutritAI Backend — FastAPI entry point."""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import create_tables
from .routers import auth_router, user_router, meal_router, nutrition_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: create database tables."""
    create_tables()
    print("[OK] Database tables created")
    yield
    print("[STOP] Shutting down")


app = FastAPI(
    title="NutritAI API",
    description="AI-powered nutritional tracking backend",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow Flutter app to connect from any origin during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(auth_router.router)
app.include_router(user_router.router)
app.include_router(meal_router.router)
app.include_router(nutrition_router.router)


@app.get("/")
def root():
    return {
        "app": "NutritAI API",
        "version": "1.0.0",
        "docs": "/docs",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}
