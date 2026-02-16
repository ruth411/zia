import logging
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
CLAUDE_API_VERSION = "2023-06-01"


async def proxy_chat_request(
    messages: list[dict[str, Any]],
    system: str | None = None,
    tools: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Forward a chat request to the Claude API and return the raw response."""
    if not settings.anthropic_api_key:
        raise ValueError("ANTHROPIC_API_KEY is not configured on the server")

    # Build Claude API request body
    body: dict[str, Any] = {
        "model": settings.claude_model,
        "max_tokens": settings.claude_max_tokens,
        "messages": messages,
    }
    if system:
        body["system"] = system
    if tools:
        body["tools"] = tools

    headers = {
        "x-api-key": settings.anthropic_api_key,
        "anthropic-version": CLAUDE_API_VERSION,
        "content-type": "application/json",
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(CLAUDE_API_URL, json=body, headers=headers)

    if response.status_code != 200:
        logger.error(f"Claude API error {response.status_code}: {response.text[:500]}")
        raise httpx.HTTPStatusError(
            f"Claude API returned {response.status_code}",
            request=response.request,
            response=response,
        )

    return response.json()
