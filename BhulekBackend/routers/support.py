"""
Support & Contact Router
Handles user feedback, support requests, and bug reports from the iOS application.
"""

import os
import json
import time
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter
from pydantic import BaseModel, Field, EmailStr

router = APIRouter()

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
SUPPORT_FILE = os.path.join(DATA_DIR, "support_messages.json")


def _ensure_data_dir():
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR, exist_ok=True)
    if not os.path.exists(SUPPORT_FILE):
        with open(SUPPORT_FILE, "w") as f:
            json.dump([], f)


class ContactRequest(BaseModel):
    name: Optional[str] = Field(None, description="User's full name")
    email: Optional[str] = Field(None, description="Contact email address")
    topic: str = Field(..., description="Inquiry category: Subscriptions, Land Records, Bug Report, Feature Request, General")
    message: str = Field(..., description="Detailed message content from user")
    user_id: Optional[str] = Field(None, description="Apple User ID if authenticated")
    app_version: Optional[str] = Field("1.0.0", description="Installed iOS App Version")
    device_info: Optional[str] = Field(None, description="Device model and iOS version")


class ContactResponse(BaseModel):
    status: str
    message: str
    ticket_id: str


@router.post(
    "/support/contact",
    response_model=ContactResponse,
    summary="Submit User Support or Contact Message",
    description="Receives support tickets, bug reports, and user feedback from the Bhumitra mobile application.",
)
async def submit_contact_message(request: ContactRequest) -> ContactResponse:
    _ensure_data_dir()
    ticket_id = f"TICK-{int(time.time())}"
    
    ticket = {
        "ticket_id": ticket_id,
        "name": request.name or "Anonymous User",
        "email": request.email or "N/A",
        "topic": request.topic,
        "message": request.message,
        "user_id": request.user_id,
        "app_version": request.app_version,
        "device_info": request.device_info,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "status": "open",
    }
    
    try:
        with open(SUPPORT_FILE, "r") as f:
            messages = json.load(f)
    except Exception:
        messages = []
    
    messages.append(ticket)
    
    with open(SUPPORT_FILE, "w") as f:
        json.dump(messages, f, indent=2)
    
    print(f"DEBUG: 📩 Received new support ticket [{ticket_id}] from {request.email or 'User'}: Topic='{request.topic}'")
    
    return ContactResponse(
        status="success",
        message="Thank you! Your message has been received. Our team will review it promptly.",
        ticket_id=ticket_id,
    )
