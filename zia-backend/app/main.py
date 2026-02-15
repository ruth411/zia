import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base
from app.routers import auth

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create database tables on startup."""
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Database tables created successfully.")
    except Exception as e:
        logger.error(f"Failed to connect to database on startup: {e}")
        logger.error("The app will start but database operations will fail.")
    yield


app = FastAPI(title="Zia Backend", version="1.0.0", lifespan=lifespan)

# CORS — allow the macOS app to make requests from any origin
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Auth routes
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])


@app.get("/health")
async def health_check():
    """Health check endpoint for Railway."""
    return {"status": "ok"}
