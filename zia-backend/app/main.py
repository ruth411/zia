import logging
import traceback
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

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


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Log full traceback for unhandled exceptions."""
    tb = traceback.format_exc()
    logger.error(f"Unhandled exception on {request.method} {request.url.path}:\n{tb}")
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc)},
    )


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


@app.get("/debug/config")
async def debug_config():
    """Temporary debug endpoint to check config resolution."""
    import os
    from urllib.parse import urlparse
    from app.config import settings

    raw_env = os.environ.get("DATABASE_URL", "NOT SET")
    resolved = settings.database_url

    # Mask credentials
    try:
        parsed = urlparse(resolved)
        masked_resolved = f"{parsed.scheme}://***@{parsed.hostname}:{parsed.port}{parsed.path}"
    except Exception:
        masked_resolved = resolved[:40] + "..."

    try:
        parsed_raw = urlparse(raw_env)
        masked_raw = f"{parsed_raw.scheme}://***@{parsed_raw.hostname}:{parsed_raw.port}{parsed_raw.path}"
    except Exception:
        masked_raw = raw_env[:40] + "..." if raw_env != "NOT SET" else "NOT SET"

    return {
        "raw_env_DATABASE_URL": masked_raw,
        "resolved_settings_database_url": masked_resolved,
        "jwt_secret_set": settings.jwt_secret != "dev-secret-change-in-production",
    }
