import logging

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse

from app.routers.auth import get_current_user
from app.schemas.chat import ChatRequest
from app.services.chat import proxy_chat_request

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/message")
async def send_message(
    request: ChatRequest,
    current_user=Depends(get_current_user),
):
    """Proxy a chat request to Claude API on behalf of an authenticated user."""
    # Convert Pydantic models to dicts for the proxy
    messages = [msg.model_dump(exclude_none=True) for msg in request.messages]
    tools = (
        [tool.model_dump(exclude_none=True) for tool in request.tools]
        if request.tools
        else None
    )

    try:
        claude_response = await proxy_chat_request(
            messages=messages,
            system=request.system,
            tools=tools,
        )
    except ValueError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Chat proxy error for user {current_user.id}: {e}")
        raise HTTPException(status_code=502, detail="Failed to get response from AI service")

    # Return raw Claude response — the Swift client already knows how to decode it
    return JSONResponse(content=claude_response)
