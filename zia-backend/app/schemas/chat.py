from typing import Any

from pydantic import BaseModel


class ContentBlock(BaseModel):
    """A content block in a Claude message (text, tool_use, or tool_result)."""
    type: str
    text: str | None = None
    id: str | None = None
    name: str | None = None
    input: dict[str, Any] | None = None
    tool_use_id: str | None = None
    content: str | None = None
    is_error: bool | None = None


class ChatMessage(BaseModel):
    """A message in the conversation."""
    role: str
    content: list[ContentBlock]


class ToolInputSchema(BaseModel):
    type: str = "object"
    properties: dict[str, Any] = {}
    required: list[str] | None = None


class ToolDefinition(BaseModel):
    name: str
    description: str
    input_schema: ToolInputSchema


class ChatRequest(BaseModel):
    """Request body for POST /chat/message."""
    messages: list[ChatMessage]
    system: str | None = None
    tools: list[ToolDefinition] | None = None
