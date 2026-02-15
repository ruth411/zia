from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/zia"
    jwt_secret: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 30

    # Claude API (server-side key)
    anthropic_api_key: str = ""
    claude_model: str = "claude-sonnet-4-20250514"
    claude_max_tokens: int = 4096

    model_config = {"env_file": ".env"}


settings = Settings()
